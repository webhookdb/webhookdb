# frozen_string_literal: true

require "webhookdb/postgres/model"
require "appydays/configurable"
require "stripe"
require "webhookdb/stripe"
require "webhookdb/jobs/replication_migration"

class Webhookdb::Organization < Webhookdb::Postgres::Model(:organizations)
  class SchemaMigrationError < StandardError; end

  plugin :timestamps
  plugin :soft_deletes
  plugin :column_encryption do |enc|
    enc.column :readonly_connection_url_raw
    enc.column :admin_connection_url_raw
  end

  configurable(:organization) do
    setting :max_query_rows, 1000
    setting :database_migration_page_size, 1000
  end

  one_to_one :subscription, class: "Webhookdb::Subscription", key: :stripe_customer_id, primary_key: :stripe_customer_id
  one_to_many :all_memberships, class: "Webhookdb::OrganizationMembership", order: :id
  one_to_many :verified_memberships,
              class: "Webhookdb::OrganizationMembership",
              conditions: {verified: true},
              adder: (->(om) { om.update(organization_id: id, verified: true) }),
              order: :id
  one_to_many :invited_memberships,
              class: "Webhookdb::OrganizationMembership",
              conditions: {verified: false},
              adder: (->(om) { om.update(organization_id: id, verified: false) }),
              order: :id
  one_to_many :service_integrations, class: "Webhookdb::ServiceIntegration", order: :id
  one_to_many :webhook_subscriptions, class: "Webhookdb::WebhookSubscription", order: :id
  many_to_many :feature_roles, class: "Webhookdb::Role", join_table: :feature_roles_organizations, right_key: :role_id
  one_to_many :all_webhook_subscriptions,
              class: "Webhookdb::WebhookSubscription",
              readonly: true,
              dataset: (lambda do |r|
                org_sints = Webhookdb::ServiceIntegration.where(organization_id: id)
                r.associated_dataset.where(
                  Sequel[organization_id: id] |
                    Sequel[service_integration_id: org_sints.select(:id)],
                )
              end)
  one_to_many :all_sync_targets,
              class: "Webhookdb::SyncTarget",
              readonly: true,
              dataset: (lambda do |r|
                org_sints = Webhookdb::ServiceIntegration.where(organization_id: id)
                r.associated_dataset.where(Sequel[service_integration_id: org_sints.select(:id)])
              end)
  one_to_many :database_migrations, class: "Webhookdb::Organization::DatabaseMigration", order: Sequel.desc(:created_at)

  def before_validation
    self.minimum_sync_seconds ||= Webhookdb::SyncTarget.default_min_period_seconds
    self.key ||= Webhookdb.to_slug(self.name)
    self.replication_schema ||= Webhookdb::Organization::DbBuilder.new(self).default_replication_schema
    super
  end

  def self.create_if_unique(params)
    self.db.transaction(savepoint: true) do
      return Webhookdb::Organization.create(name: params[:name])
    end
  rescue Sequel::UniqueConstraintViolation
    return nil
  end

  def admin_customers
    return self.verified_memberships.filter(&:admin?).map(&:customer)
  end

  def cli_editable_fields
    return ["name", "billing_email"]
  end

  def self.lookup_by_identifier(identifier)
    # Check to see if identifier is an integer, i.e. an ID.
    # Otherwise treat it as a slug
    org = if /\A\d+\z/.match?(identifier)
            Webhookdb::Organization[id: identifier]
          else
            Webhookdb::Organization[key: identifier]
          end
    return org
  end

  def readonly_connection(**kw, &)
    return Webhookdb::ConnectionCache.borrow(self.readonly_connection_url_raw, **kw, &)
  end

  def admin_connection(**kw, &)
    return Webhookdb::ConnectionCache.borrow(self.admin_connection_url_raw, **kw, &)
  end

  def execute_readonly_query(sql)
    return self.readonly_connection do |conn|
      ds = conn.fetch(sql)
      r = QueryResult.new
      r.columns = ds.columns
      r.rows = []
      ds.each do |row|
        if r.rows.length >= self.class.max_query_rows
          r.max_rows_reached = true
          break
        end
        r.rows << row.values
      end
      return r
    end
  end

  class QueryResult
    attr_accessor :rows, :columns, :max_rows_reached
  end

  # Return the readonly connection url, with the host set to public_host if set.
  def readonly_connection_url
    return self._public_host_connection_url(self.readonly_connection_url_raw)
  end

  # Return the admin connection url, with the host set to public_host if set.
  def admin_connection_url
    return self._public_host_connection_url(self.admin_connection_url_raw)
  end

  # Replace the host of the given URL with public_host if it is set,
  # or return u if not.
  #
  # It's very important we store the 'raw' URL to the actual host,
  # and the public host separately. This will allow us to, for example,
  # modify the org to point to a new host,
  # and then update the CNAME (finding it based on the public_host name)
  # to point to that host.
  protected def _public_host_connection_url(u)
    return u if self.public_host.blank?
    uri = URI(u)
    uri.host = self.public_host
    return uri.to_s
  end

  def dbname
    raise Webhookdb::InvalidPrecondition, "no db has been created, call prepare_database_connections first" if
      self.admin_connection_url.blank?
    return URI(self.admin_connection_url).path.tr("/", "")
  end

  def admin_user
    ur = URI(self.admin_connection_url)
    return ur.user
  end

  def readonly_user
    ur = URI(self.readonly_connection_url)
    return ur.user
  end

  # In cases where the readonly and admin user are the same, we sometimes adapt queries
  # to prevent revoking admin db priviliges.
  def single_db_user?
    return self.admin_user == self.readonly_user
  end

  def display_string
    return "#{self.name} (#{self.key})"
  end

  def prepare_database_connections?
    self.prepare_database_connections unless self.admin_connection_url.present?
  end

  # Build the org-specific users, database, and set our connection URLs to it.
  def prepare_database_connections
    self.db.transaction do
      self.lock!
      raise Webhookdb::InvalidPrecondition, "connections already set" if self.admin_connection_url.present?
      builder = Webhookdb::Organization::DbBuilder.new(self)
      builder.prepare_database_connections
      self.admin_connection_url_raw = builder.admin_url
      self.readonly_connection_url_raw = builder.readonly_url
      self.save_changes
    end
  end

  # Create a CNAME in Cloudflare for the currently configured connection urls.
  def create_public_host_cname
    self.db.transaction do
      self.lock!
      # We must have a host to create a CNAME to.
      raise Webhookdb::InvalidPrecondition, "connection urls must be set" if self.readonly_connection_url_raw.blank?
      # Should only be used once when creating the org DBs.
      raise Webhookdb::InvalidPrecondition, "public_host must not be set" if self.public_host.present?
      # Use the raw URL, even though we know at this point
      # public_host is empty so raw and public host urls are the same.
      Webhookdb::Organization::DbBuilder.new(self).create_public_host_cname(self.readonly_connection_url_raw)
      self.save_changes
    end
  end

  # Delete the org-specific database and remove the org connection strings.
  # Use this when an org is to be deleted (either for real, or in test teardown).
  def remove_related_database
    self.db.transaction do
      self.lock!
      Webhookdb::Organization::DbBuilder.new(self).remove_related_database
      self.admin_connection_url_raw = ""
      self.readonly_connection_url_raw = ""
      self.save_changes
    end
  end

  def self.enqueue_migrate_all_replication_tables
    Webhookdb::Organization.each do |org|
      Webhookdb::Jobs::ReplicationMigration.perform_async(org.id)
    end
  end

  # Get all the table names and column names for all integrations in the org
  # Find any of those table/column pairs that are not present in information_schema.columns
  # Ensure all columns for those integrations/tables.
  def migrate_replication_tables
    tables = self.service_integrations.map(&:table_name)
    sequences = self.db[Sequel[:information_schema][:sequences]].
      grep(:sequence_name, "replicator_seq_org_#{self.id}_%").
      select_map(:sequence_name).
      to_set
    cols_in_db = self.admin_connection do |db|
      db[Sequel[:information_schema][:columns]].
        where(table_schema: self.replication_schema, table_name: tables).
        select(
          :table_name,
          Sequel.function(:array_agg, :column_name).cast("text[]").as(:columns),
        ).
        group_by(:table_name).
        all.
        to_h { |c| [c[:table_name], c[:columns]] }
    end

    self.service_integrations.each do |sint|
      svc = sint.service_instance
      existing_columns = cols_in_db.fetch(sint.table_name) { [] }
      all_col_names = svc.storable_columns.map(&:name).map(&:to_s)
      all_cols_exist_in_db = (all_col_names - existing_columns).empty?
      svc.ensure_all_columns unless all_cols_exist_in_db
      sint.ensure_sequence(skip_check: true) if svc.requires_sequence? && !sequences.include?(sint.sequence_name)
    end
  end

  # Modify the admin and readonly users to have new usernames and passwords.
  def roll_database_credentials
    self.db.transaction do
      self.lock!
      builder = Webhookdb::Organization::DbBuilder.new(self)
      builder.roll_connection_credentials
      self.admin_connection_url_raw = builder.admin_url
      self.readonly_connection_url_raw = builder.readonly_url
      self.save_changes
    end
  end

  def migrate_replication_schema(schema)
    unless Webhookdb::DBAdapter::VALID_IDENTIFIER.match?(schema)
      msg = "Sorry, this is not a valid schema name. " + Webhookdb::DBAdapter::INVALID_IDENTIFIER_MESSAGE
      raise SchemaMigrationError, msg
    end
    Webhookdb::Organization::DatabaseMigration.guard_ongoing!(self)
    raise SchemaMigrationError, "destination and target schema are the same" if schema == self.replication_schema
    builder = Webhookdb::Organization::DbBuilder.new(self)
    sql = builder.migration_replication_schema_sql(self.replication_schema, schema)
    self.admin_connection(transaction: true) do |db|
      db << sql
    end
    self.update(replication_schema: schema)
  end

  def register_in_stripe
    raise Webhookdb::InvalidPrecondition, "org already in Stripe" if self.stripe_customer_id.present?
    stripe_customer = Stripe::Customer.create(
      {
        name: self.name,
        email: self.billing_email,
        metadata: {
          org_id: self.id,
        },
      },
    )
    self.stripe_customer_id = stripe_customer.id
    self.save_changes
    return stripe_customer
  end

  def get_stripe_billing_portal_url
    raise Webhookdb::InvalidPrecondition, "organization must be registered in Stripe" if self.stripe_customer_id.blank?
    session = Stripe::BillingPortal::Session.create(
      {
        customer: self.stripe_customer_id,
        return_url: Webhookdb.app_url + "/jump/portal-return",
      },
    )

    return session.url
  end

  def get_stripe_checkout_url(price_id)
    raise Webhookdb::InvalidPrecondition, "organization must be registered in Stripe" if self.stripe_customer_id.blank?
    session = Stripe::Checkout::Session.create(
      {
        customer: self.stripe_customer_id,
        cancel_url: Webhookdb.app_url + "/jump/checkout-cancel",
        line_items: [{
          price: price_id, quantity: 1,
        }],
        mode: "subscription",
        payment_method_types: ["card"],
        allow_promotion_codes: true,
        success_url: Webhookdb.app_url + "/jump/checkout-success",
      },
    )

    return session.url
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

  # SUBSCRIPTION PERMISSIONS

  def active_subscription?
    subscription = Webhookdb::Subscription[stripe_customer_id: self.stripe_customer_id]
    # return false if no subscription
    return false if subscription.nil?
    # otherwise check stripe subscription string
    return ["trialing", "active", "past due"].include? subscription.status
  end

  def can_add_new_integration?
    # if the sint's organization has an active subscription, return true
    return true if self.active_subscription?
    # if there is no active subscription, check number of integrations against free tier max
    limit = Webhookdb::Subscription.max_free_integrations
    return Webhookdb::ServiceIntegration.where(organization: self).count < limit
  end

  def available_service_names
    available = Webhookdb::Services.registered.values.filter do |desc|
      # The org must have any of the flags required for the service. In other words,
      # the intersection of desc[:feature_roles] & org.feature_roles must
      # not be empty
      no_restrictions = desc.feature_roles.empty?
      next true if no_restrictions
      org_has_access = (self.feature_roles.map(&:name) & desc.feature_roles).present?
      org_has_access
    end
    return available.map(&:name)
  end

  #
  # :section: Validations
  #

  def validate
    super
    validates_all_or_none(:admin_connection_url_raw, :readonly_connection_url_raw, predicate: :present?)
    validates_format(/^[a-z][a-z0-9_]*$/, :key, message: "is not valid as a CNAME")
    validates_max_length 63, :key, message: "is not valid as a CNAME"
  end

  # @!attribute service_integrations
  #   @return [Array<Webhookdb::ServiceIntegration>]
end

require "webhookdb/organization/db_builder"

# Table: organizations
# ------------------------------------------------------------------------------------------------------------------------------------------------------------
# Columns:
#  id                          | integer                  | PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY
#  created_at                  | timestamp with time zone | NOT NULL DEFAULT now()
#  updated_at                  | timestamp with time zone |
#  soft_deleted_at             | timestamp with time zone |
#  name                        | text                     | NOT NULL
#  key                         | text                     |
#  billing_email               | text                     | NOT NULL DEFAULT ''::text
#  stripe_customer_id          | text                     | NOT NULL DEFAULT ''::text
#  readonly_connection_url_raw | text                     |
#  admin_connection_url_raw    | text                     |
#  public_host                 | text                     | NOT NULL DEFAULT ''::text
#  cloudflare_dns_record_json  | jsonb                    | NOT NULL DEFAULT '{}'::jsonb
#  replication_schema          | text                     | NOT NULL
#  job_semaphore_size          | integer                  | NOT NULL DEFAULT 10
# Indexes:
#  organizations_pkey     | PRIMARY KEY btree (id)
#  organizations_key_key  | UNIQUE btree (key)
#  organizations_name_key | UNIQUE btree (name)
# Referenced By:
#  feature_roles_organizations      | feature_roles_organizations_organization_id_fkey      | (organization_id) REFERENCES organizations(id)
#  logged_webhooks                  | logged_webhooks_organization_id_fkey                  | (organization_id) REFERENCES organizations(id) ON DELETE CASCADE
#  organization_database_migrations | organization_database_migrations_organization_id_fkey | (organization_id) REFERENCES organizations(id) ON DELETE CASCADE
#  organization_memberships         | organization_memberships_organization_id_fkey         | (organization_id) REFERENCES organizations(id)
#  service_integrations             | service_integrations_organization_id_fkey             | (organization_id) REFERENCES organizations(id)
#  webhook_subscriptions            | webhook_subscriptions_organization_id_fkey            | (organization_id) REFERENCES organizations(id)
# ------------------------------------------------------------------------------------------------------------------------------------------------------------
