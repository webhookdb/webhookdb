# frozen_string_literal: true

require "appydays/configurable"
require "bcrypt"
require "openssl"
require "webhookdb/id"
require "webhookdb/postgres/model"

class Webhookdb::Customer < Webhookdb::Postgres::Model(:customers)
  extend Webhookdb::MethodUtilities
  include Appydays::Configurable

  class InvalidPassword < StandardError; end
  class SignupDisabled < StandardError; end

  configurable(:customer) do
    setting :signup_email_allowlist, ["*"], convert: ->(s) { s.split }
    setting :skip_authentication, false
    setting :skip_authentication_allowlist, [], convert: ->(s) { s.split }
  end

  # The bcrypt hash cost. Changing this would invalidate all passwords!
  # It's only here so we can change it for testing.
  singleton_attr_accessor :password_hash_cost
  @password_hash_cost = 10

  MIN_PASSWORD_LENGTH = 8

  # A bcrypt digest that's valid, but not a real digest. Used as a placeholder for
  # accounts with no passwords, which makes them impossible to authenticate. Or at
  # least much less likely than with a random string.
  PLACEHOLDER_PASSWORD_DIGEST = "$2a$11$....................................................."

  # Regex that matches the prefix of a deleted user's email
  DELETED_EMAIL_PATTERN = /^(?<prefix>\d+(?:\.\d+)?)\+(?<rest>.*)$/

  plugin :timestamps
  plugin :soft_deletes

  one_to_many :all_memberships, class: "Webhookdb::OrganizationMembership"
  one_to_many :invited_memberships,
              class: "Webhookdb::OrganizationMembership",
              conditions: {verified: false},
              adder: ->(om) { om.update(customer_id: id, verified: false) }
  one_to_many :verified_memberships,
              class: "Webhookdb::OrganizationMembership",
              conditions: {verified: true},
              adder: ->(om) { om.update(customer_id: id, verified: true) }
  one_to_one :default_membership, class: "Webhookdb::OrganizationMembership", conditions: {is_default: true}
  one_to_many :message_deliveries, key: :recipient_id, class: "Webhookdb::Message::Delivery"
  one_to_many :reset_codes, class: "Webhookdb::Customer::ResetCode", order: Sequel.desc([:created_at])
  many_to_many :roles, class: "Webhookdb::Role", join_table: :roles_customers

  dataset_module do
    def with_email(*emails)
      emails = emails.map { |e| e.downcase.strip }
      return self.where(email: emails)
    end
  end

  def self.with_email(e)
    return self.dataset.with_email(e).first
  end

  def self.find_or_create_for_email(email)
    email = email.strip.downcase
    # If there is no Customer object associated with the email, create one
    me = Webhookdb::Customer[email:]
    return [false, me] if me
    signup_allowed = self.signup_email_allowlist.any? { |pattern| File.fnmatch(pattern, email) }
    raise SignupDisabled unless signup_allowed
    return [true, Webhookdb::Customer.create(email:, password: SecureRandom.hex(32))]
  end

  # Make sure the customer has a default organization.
  # New registrants, or users who have been invited (so have an existing customer and invited org)
  # get an org created. Default orgs must already be verified as per a DB constraint.
  # @return [Array<TrueClass,FalseClass,Webhookdb::OrganizationMembership>] Tuple of [created, membership]
  def self.find_or_create_default_organization(customer)
    mem = customer.default_membership
    return [false, mem] if mem
    email = customer.email
    # We could have no default, but already be in an organization, like if the default was deleted.
    mem = customer.verified_memberships.first
    return [false, mem] if mem
    # We have no verified orgs, so create one.
    # TODO: this will fail if not unique. We need to make sure we pick a unique name/key.
    self_org = Webhookdb::Organization.create(name: "#{email} Org", billing_email: email.to_s)
    mem = customer.add_membership(
      organization: self_org, membership_role: Webhookdb::Role.admin_role, verified: true, is_default: true,
    )
    return [true, mem]
  end

  # @return Tuple of <Step, Customer>.
  def self.register_or_login(email:)
    self.db.transaction do
      customer_created, me = self.find_or_create_for_email(email)
      org_created, _membership = self.find_or_create_default_organization(me)
      me.reset_codes_dataset.usable.each(&:expire!)
      me.add_reset_code(transport: "email")
      step = Webhookdb::Replicator::StateMachineStep.new
      step.output = if customer_created || org_created
                      %(To finish registering, please look for an email we just sent to #{email}.
It contains a One Time Password code to validate your email.
)
      else
        %(Hello again!

To finish logging in, please look for an email we just sent to #{email}.
It contains a One Time Password used to log in.
)
                    end
      step.output += %(You can enter it here, or if you want to finish up from a new prompt, use:

  webhookdb auth login --username=#{email} --token=<#{Webhookdb::Customer::ResetCode::TOKEN_LENGTH} digit token>
)
      step.prompt = "Enter the token from your email:"
      step.prompt_is_secret = true
      step.needs_input = true
      step.post_to_url = "/v1/auth"
      step.post_params = {email:}
      step.post_params_value_key = "token"
      return [step, me]
    end
  end

  # @return Tuple of <Step, Customer>. Customer is nil if token was invalid.
  def self.finish_otp(me, token:)
    if me.nil?
      step = Webhookdb::Replicator::StateMachineStep.new
      step.output = %(Sorry, no one with that email exists. Try running:

  webhookdb auth login [email]
      )
      step.needs_input = false
      step.complete = true
      step.error_code = "email_not_exist"
      return [step, nil]
    end

    unless me.should_skip_authentication?
      begin
        Webhookdb::Customer::ResetCode.use_code_with_token(token) do |code|
          raise Webhookdb::Customer::ResetCode::Unusable unless code.customer === me
          code.customer.save_changes
          me.refresh
        end
      rescue Webhookdb::Customer::ResetCode::Unusable
        step = Webhookdb::Replicator::StateMachineStep.new
        step.output = %(Sorry, that token is invalid. Please try again.
If you have not gotten a code, use Ctrl+C to close this prompt and request a new code:

  webhookdb auth login #{me.email}
)
        step.error_code = "invalid_otp"
        step.prompt_is_secret = true
        step.prompt = "Enter the token from your email:"
        step.needs_input = true
        step.post_to_url = "/v1/auth"
        step.post_params = {email: me.email}
        step.post_params_value_key = "token"
        return [step, nil]
      end
    end

    welcome_tutorial = "Quick tip: Use `webhookdb services list` to see what services are available."
    if me.invited_memberships.present?
      welcome_tutorial = "You have the following pending invites:\n\n" +
        me.invited_memberships.map { |om| "  #{om.organization.display_string}: #{om.invitation_code}" }.join("\n") +
        "\n\nUse `webhookdb org join [code]` to accept an invitation."
    end
    step = Webhookdb::Replicator::StateMachineStep.new
    step.output = %(Welcome! For help getting started, please check out
our docs at https://docs.webhookdb.com.

#{welcome_tutorial})
    step.needs_input = false
    step.complete = true
    return [step, me]
  end

  # If the SKIP_PHONE|EMAIL_VERIFICATION are set, verify the phone/email.
  # Also verify phone and email if the customer email matches the allowlist.
  def should_skip_authentication?
    return true if self.class.skip_authentication
    return true if self.class.skip_authentication_allowlist.any? { |pattern| File.fnmatch(pattern, self.email) }
    return false
  end

  def ensure_role(role_or_name)
    role = role_or_name.is_a?(Webhookdb::Role) ? role_or_name : Webhookdb::Role[name: role_or_name]
    raise "No role for #{role_or_name}" unless role.present?
    self.add_role(role) unless self.roles_dataset[role.id]
  end

  def admin?
    return self.roles.include?(Webhookdb::Role.admin_role)
  end

  def greeting
    return self.name.present? ? self.name : "there"
  end

  #
  # :section: Memberships
  #

  def add_membership(opts={})
    if !opts.is_a?(Webhookdb::OrganizationMembership) && !opts.key?(:verified)
      raise ArgumentError, "must pass :verified or a model into add_membership, it is ambiguous otherwise"
    end
    self.associations.delete(opts[:verified] ? :verified_memberships : :invited_memberships)
    return self.add_all_membership(opts)
  end

  def verified_member_of?(org)
    return !org.verified_memberships_dataset.where(customer_id: self.id).empty?
  end

  def default_organization
    return self.default_membership&.organization
  end

  def replace_default_membership(new_mem)
    self.verified_memberships_dataset.update(is_default: false)
    self.associations.delete(:verified_memberships)
    new_mem.update(is_default: true)
  end

  #
  # :section: Password
  #

  ### Fetch the user's password as an BCrypt::Password object.
  def encrypted_password
    digest = self.password_digest or return nil
    return BCrypt::Password.new(digest)
  end

  ### Set the password to the given +unencrypted+ String.
  def password=(unencrypted)
    if unencrypted
      self.check_password_complexity(unencrypted)
      self.password_digest = BCrypt::Password.create(unencrypted, cost: self.class.password_hash_cost)
    else
      self.password_digest = BCrypt::Password.new(PLACEHOLDER_PASSWORD_DIGEST)
    end
  end

  ### Attempt to authenticate the user with the specified +unencrypted+ password. Returns
  ### +true+ if the password matched.
  def authenticate(unencrypted)
    return false unless unencrypted
    return false if self.soft_deleted?
    return self.encrypted_password == unencrypted
  end

  protected def new_password_matches?(unencrypted)
    existing_pw = BCrypt::Password.new(self.password_digest)
    new_pw = self.digest_password(unencrypted)
    return existing_pw == new_pw
  end

  ### Raise if +unencrypted+ password does not meet complexity requirements.
  protected def check_password_complexity(unencrypted)
    raise Webhookdb::Customer::InvalidPassword, "password must be at least %d characters." % [MIN_PASSWORD_LENGTH] if
      unencrypted.length < MIN_PASSWORD_LENGTH
  end

  #
  # :section: Phone
  #

  def us_phone
    return Phony.format(self.phone, format: :national)
  end

  def us_phone=(s)
    self.phone = Webhookdb::PhoneNumber::US.normalize(s)
  end

  def unverified?
    return !self.email_verified? && !self.phone_verified?
  end

  #
  # :section: Sequel Hooks
  #

  def before_create
    self[:opaque_id] ||= Webhookdb::Id.new_opaque_id("cus")
  end

  ### Soft-delete hook -- prep the user for deletion.
  def before_soft_delete
    self.email = "#{Time.now.to_f}+#{self[:email]}"
    self.password = "aA1!#{SecureRandom.hex(8)}"
    super
  end

  ### Soft-delete hook -- expire unused, unexpired reset codes and
  ### trigger an event on removal.

  #
  # :section: Sequel Validation
  #

  def validate
    super
    self.validates_presence(:email)
    self.validates_format(/[[:graph:]]+@[[:graph:]]+\.[a-zA-Z]{2,}/, :email)
    self.validates_unique(:email)
    self.validates_operator(:==, self.email&.downcase&.strip, :email)
  end
end

# Table: customers
# -----------------------------------------------------------------------------------------------------------------------------------------------------
# Columns:
#  id              | integer                  | PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY
#  created_at      | timestamp with time zone | NOT NULL DEFAULT now()
#  updated_at      | timestamp with time zone |
#  soft_deleted_at | timestamp with time zone |
#  password_digest | text                     | NOT NULL
#  email           | citext                   | NOT NULL
#  name            | text                     | NOT NULL DEFAULT ''::text
#  note            | text                     | NOT NULL DEFAULT ''::text
#  opaque_id       | text                     | NOT NULL
# Indexes:
#  customers_pkey          | PRIMARY KEY btree (id)
#  customers_email_key     | UNIQUE btree (email)
#  customers_opaque_id_key | UNIQUE btree (opaque_id)
# Check constraints:
#  lowercase_nospace_email | (email::text = btrim(lower(email::text)))
# Referenced By:
#  backfill_jobs                    | backfill_jobs_created_by_id_fkey                    | (created_by_id) REFERENCES customers(id) ON DELETE SET NULL
#  customer_reset_codes             | customer_reset_codes_customer_id_fkey               | (customer_id) REFERENCES customers(id) ON DELETE CASCADE
#  message_deliveries               | message_deliveries_recipient_id_fkey                | (recipient_id) REFERENCES customers(id) ON DELETE SET NULL
#  organization_database_migrations | organization_database_migrations_started_by_id_fkey | (started_by_id) REFERENCES customers(id) ON DELETE SET NULL
#  organization_memberships         | organization_memberships_customer_id_fkey           | (customer_id) REFERENCES customers(id)
#  roles_customers                  | roles_customers_customer_id_fkey                    | (customer_id) REFERENCES customers(id)
#  sync_targets                     | sync_targets_created_by_id_fkey                     | (created_by_id) REFERENCES customers(id) ON DELETE SET NULL
#  webhook_subscriptions            | webhook_subscriptions_created_by_id_fkey            | (created_by_id) REFERENCES customers(id)
# -----------------------------------------------------------------------------------------------------------------------------------------------------
