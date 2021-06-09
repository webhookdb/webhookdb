# frozen_string_literal: true

require "appydays/configurable"
require "bcrypt"
require "openssl"
require "webhookdb/postgres/model"

class Webhookdb::Customer < Webhookdb::Postgres::Model(:customers)
  extend Webhookdb::MethodUtilities
  include Appydays::Configurable

  class InvalidPassword < RuntimeError; end

  configurable(:customer) do
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
  DELETED_EMAIL_PATTERN = /^(?<prefix>\d+(?:\.\d+)?)\+(?<rest>.*)$/.freeze

  plugin :timestamps
  plugin :soft_deletes

  one_to_many :memberships, class: "Webhookdb::OrganizationMembership"
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

  # Helper function for dealing with organization memberships
  def verified_member_of?(org)
    return !org.memberships_dataset[customer_id: self.id, verified: true].nil?
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

  def default_org_key
    default_org_membership = self.memberships_dataset.first
    return default_org_membership.organization.key unless default_org_membership.nil?
    return
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
    self.validates_unique(:email)
    self.validates_operator(:==, self.email.downcase.strip, :email)
  end
end

# Table: customers
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Columns:
#  id                            | integer                  | PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY
#  created_at                    | timestamp with time zone | NOT NULL DEFAULT now()
#  updated_at                    | timestamp with time zone |
#  soft_deleted_at               | timestamp with time zone |
#  password_digest               | text                     | NOT NULL
#  email                         | citext                   | NOT NULL
#  email_verified_at             | timestamp with time zone |
#  phone                         | text                     | NOT NULL
#  phone_verified_at             | timestamp with time zone |
#  first_name                    | text                     | NOT NULL DEFAULT ''::text
#  last_name                     | text                     | NOT NULL DEFAULT ''::text
#  note                          | text                     | NOT NULL DEFAULT ''::text
#  timezone                      | text                     | NOT NULL DEFAULT 'America/Los_Angeles'::text
#  registered_env                | text                     | NOT NULL
#  expo_push_notification_tokens | text[]                   | NOT NULL DEFAULT '{}'::text[]
# Indexes:
#  customers_pkey      | PRIMARY KEY btree (id)
#  customers_email_key | UNIQUE btree (email)
#  customers_phone_key | UNIQUE btree (phone)
# Check constraints:
#  lowercase_nospace_email | (email::text = btrim(lower(email::text)))
#  numeric_phone           | (phone ~ '^[0-9]{11,15}$'::text)
# Referenced By:
#  customer_expo_push_notification_receipts | customer_expo_push_notification_receipts_customer_id_fkey | (customer_id) REFERENCES customers(id) ON DELETE CASCADE
#  customer_reset_codes                     | customer_reset_codes_customer_id_fkey                     | (customer_id) REFERENCES customers(id) ON DELETE CASCADE
#  roles_customers                          | roles_customers_customer_id_fkey                          | (customer_id) REFERENCES customers(id)
#  message_deliveries                       | message_deliveries_recipient_id_fkey                      | (recipient_id) REFERENCES customers(id) ON DELETE SET NULL
#  customer_journeys                        | customer_journeys_customer_id_fkey                        | (customer_id) REFERENCES customers(id) ON DELETE CASCADE
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------
