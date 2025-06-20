# frozen_string_literal: true

require "webhookdb/postgres/model"
require "appydays/configurable"
require "stripe"
require "webhookdb/stripe"
require "webhookdb/jobs/replication_migration"

class Webhookdb::Organization < Webhookdb::Postgres::Model(:organizations)
  include Webhookdb::Admin::Linked

  class SchemaMigrationError < Webhookdb::ProgrammingError; end

  plugin :timestamps
  plugin :soft_deletes
  plugin :text_searchable, terms: [:name, :key, :billing_email]
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
              adder: ->(om) { om.update(organization_id: id, verified: true) },
              order: :id
  one_to_many :invited_memberships,
              class: "Webhookdb::OrganizationMembership",
              conditions: {verified: false},
              adder: ->(om) { om.update(organization_id: id, verified: false) },
              order: :id
  one_to_many :service_integrations, class: "Webhookdb::ServiceIntegration", order: :id
  one_to_many :error_handlers, class: "Webhookdb::Organization::ErrorHandler", order: :id
  one_to_many :saved_queries, class: "Webhookdb::SavedQuery", order: :id
  one_to_many :saved_views, class: "Webhookdb::SavedView", order: :id
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
              end),
              eager_loader: (lambda do |eo|
                               org_ids = eo[:id_map].keys
                               all_subs = Webhookdb::WebhookSubscription.
                                 left_join(:service_integrations, {id: :service_integration_id}).
                                 select(
                                   Sequel[:webhook_subscriptions][Sequel.lit("*")],
                                   Sequel[:service_integrations][:organization_id].as(:_sint_org_id),
                                 ).where(
                                   Sequel[Sequel[:webhook_subscriptions][:organization_id] => org_ids] |
                                     Sequel[Sequel[:service_integrations][:organization_id] => org_ids],
                                 ).all
                               all_subs_by_org = all_subs.group_by { |sub| sub[:organization_id] || sub[:_sint_org_id] }
                               eo[:rows].each do |org|
                                 org.associations[:all_webhook_subscriptions] = all_subs_by_org.fetch(org.id, [])
                               end
                             end)
  many_through_many :all_sync_targets,
                    [
                      [:service_integrations, :organization_id, :id],
                    ],
                    class: "Webhookdb::SyncTarget",
                    left_primary_key: :id,
                    right_primary_key: :service_integration_id,
                    read_only: true,
                    order: [:created_at, :id]
  one_to_many :database_migrations, class: "Webhookdb::Organization::DatabaseMigration", order: Sequel.desc(:created_at)

  dataset_module do
    # Return orgs with the given id (if identifier is an integer), or key or name.
    def with_identifier(identifier)
      return self.where(id: identifier.to_i) if /^\d+$/.match?(identifier)
      ds = self.where(Sequel[key: identifier] | Sequel[name: identifier])
      return ds
    end
  end

  def log_tags
    return {
      organization_id: self.id,
      organization_key: self.key,
    }
  end

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

  def alerting
    return @alerting ||= Alerting.new(self)
  end

  def cli_editable_fields
    return ["name", "billing_email"]
  end

  def readonly_connection(**kw, &)
    return Webhookdb::ConnectionCache.borrow(self.readonly_connection_url_raw, **kw, &)
  end

  def admin_connection(**kw, &)
    return Webhookdb::ConnectionCache.borrow(self.admin_connection_url_raw, **kw, &)
  end

  def superuser_url_raw!
    org_uri = URI(self.admin_connection_url_raw)
    superuser_url = Webhookdb::Organization::DbBuilder.available_server_urls.find { |u| URI(u).host == org_uri.host }
    raise Webhookdb::InvalidPrecondition, "cannot find superuser url for #{org_uri.host}" if superuser_url.nil?
    return superuser_url
  end

  def superuser_url_to_database!
    u = URI(superuser_url_raw!)
    u.path = URI(self.admin_connection_url_raw).path
    return u.to_s
  end

  def execute_readonly_query(sql)
    max_rows = self.max_query_rows || self.class.max_query_rows
    return self.readonly_connection do |conn|
      ds = conn.fetch(sql)
      r = QueryResult.new
      r.max_rows_reached = false
      r.columns = ds.columns
      r.rows = []
      # Stream to avoid pulling in all rows of unlimited queries
      ds.stream.each do |row|
        if r.rows.length >= max_rows
          r.max_rows_reached = true
          break
        end
        r.rows << row.values
      end
      return r
    end
  end

  # Run the given SQL inside the org, and use special error handling if it fails.
  # @return [Array<Webhookdb::Organization::QueryResult,String,nil>] Tuple of query result, and optional message.
  #   On query success, return <QueryResult, nil>.
  #   On DatabaseError, return <nil, message>.
  #   On other types of errors, raise.
  def execute_readonly_query_with_help(sql)
    result = self.execute_readonly_query(sql)
    return result, nil
  rescue Sequel::DatabaseError => e
    self.logger.error("db_query_database_error", e)
    # We want to handle InsufficientPrivileges and UndefinedTable explicitly
    # since we can hint the user at what to do.
    # Otherwise, we should just return the Postgres exception.
    msg = ""
    case e.wrapped_exception
      when PG::UndefinedTable
        missing_table = e.wrapped_exception.message.match(/relation (.+) does not/)&.captures&.first
        msg = "The table #{missing_table} does not exist. Run `webhookdb db tables` to see available tables." if
          missing_table
      when PG::InsufficientPrivilege
        msg = "You do not have permission to perform this query. Queries must be read-only."
      else
        msg = e.wrapped_exception.message
    end
    return [nil, msg]
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

  # @return [Webhookdb::Organization::DbBuilder]
  def db_builder = Webhookdb::Organization::DbBuilder.new(self)

  def prepare_database_connections? = self.prepare_database_connections(safe: true)

  # Build the org-specific users, database, and set our connection URLs to it.
  # @param safe [*] If true, noop if connection urls are set.
  def prepare_database_connections(safe: false)
    self.db.transaction do
      self.lock!
      if self.admin_connection_url.present?
        return if safe
        raise Webhookdb::InvalidPrecondition, "connections already set"
      end
      builder = self.db_builder
      builder.prepare_database_connections
      self.admin_connection_url_raw = builder.admin_url
      self.readonly_connection_url_raw = builder.readonly_url
      self.save_changes
    end
  end

  # Create a CNAME in Cloudflare for the currently configured connection urls.
  # @param safe [*] If true, noop if the public host is set.
  def create_public_host_cname(safe: false)
    self.db.transaction do
      self.lock!
      # We must have a host to create a CNAME to.
      raise Webhookdb::InvalidPrecondition, "connection urls must be set" if self.readonly_connection_url_raw.blank?
      # Should only be used once when creating the org DBs.
      if self.public_host.present?
        return if safe
        raise Webhookdb::InvalidPrecondition, "public_host must not be set"
      end
      # Use the raw URL, even though we know at this point
      # public_host is empty so raw and public host urls are the same.
      self.db_builder.create_public_host_cname(self.readonly_connection_url_raw)
      self.save_changes
    end
  end

  # Delete the org-specific database and remove the org connection strings.
  # Use this when an org is to be deleted (either for real, or in test teardown).
  def remove_related_database
    self.db.transaction do
      self.lock!
      self.db_builder.remove_related_database
      self.admin_connection_url_raw = ""
      self.readonly_connection_url_raw = ""
      self.save_changes
    end
  end

  # As part of the release process, we enqueue a job that will migrate the replication schemas
  # for all organizations. However this job must use the NEW code being released;
  # it should not use the CURRENT code the workers may be using when this method is run
  # during the release process.
  #
  # We can get around this by enqueing the jobs with the 'target' release creation date.
  # Only jobs that execute with this release creation date will perform the migration;
  # if the job is running using an older release creation date (ie still running old code),
  # it will re-enqueue the migration to run in the future, using a worker that will eventually
  # be using newer code.
  #
  # For example:
  #
  # - We have Release A, created at 0, currently running.
  # - Release B, created at 1, runs this method.
  # - The workers, using Release A code (with a release_created_at of 0),
  #   run the ReplicationMigration job.
  #   They see the target release_created_at of 1 is greater than/after the current release_created_at of 0,
  #   so re-enqueue the job.
  # - Eventually the workers are using Release B code, which has a release_created_at of 1.
  #   This matches the target, so the job is run.
  #
  # For a more complex example, which involves releases created in quick succession
  # (we need to be careful to avoid jobs that never run):
  #
  # - We have Release A, created at 0, currently running.
  # - Release B, created at 1, runs this method.
  # - Release C, created at 2, runs this method.
  # - Workers are backed up, so nothing is processed until all workers are using Release C.
  # - Workers using Release C code process two sets of jobs:
  #   - Jobs with a target release_created_at of 1
  #   - Jobs with a target release_created_at of 2
  # - Jobs with a target of 2 run the actual migration, because the times match.
  # - Jobs with a target of 1, see that the target is less than/before current release_created_at of 2.
  #   This indicates the migration is stale, and the job is discarded.
  #
  # NOTE: There will always be a race condition where we may process webhooks using the new code,
  # before we've migrated the replication schemas into the new code. This will error during the upsert
  # because the column doesn't yet exist. However these will be retried automatically,
  # and quickly, so we don't worry about them yet.
  def self.enqueue_migrate_all_replication_tables
    Webhookdb::Organization.each do |org|
      Webhookdb::Jobs::ReplicationMigration.perform_in(2, org.id, Webhookdb::RELEASE_CREATED_AT)
    end
  end

  # Get all the table names and column names for all integrations in the org
  # Find any of those table/column pairs that are not present in information_schema.columns
  # Ensure all columns for those integrations/tables.
  def migrate_replication_tables
    tables = self.service_integrations.map(&:table_name)
    sequences_in_app_db = self.db[Sequel[:information_schema][:sequences]].
      grep(:sequence_name, "replicator_seq_org_#{self.id}_%").
      select_map(:sequence_name).
      to_set
    cols_in_org_db = {}
    indexes_in_org_db = []
    self.admin_connection do |db|
      cols_in_org_db = db[Sequel[:information_schema][:columns]].
        where(table_schema: self.replication_schema, table_name: tables).
        select(
          :table_name,
          Sequel.function(:array_agg, :column_name).cast("text[]").as(:columns),
        ).
        group_by(:table_name).
        all.
        to_h { |c| [c[:table_name], c[:columns]] }
      db[Sequel[:pg_indexes]].
        where(schemaname: self.replication_schema, tablename: tables).
        select_map([:tablename, :indexname]).
        each do |(tbl, idx)|
          indexes_in_org_db << Sequel[tbl.to_sym][idx.to_sym]
        end
    end

    self.service_integrations.each do |sint|
      svc = sint.replicator
      existing_columns = cols_in_org_db.fetch(sint.table_name) { [] }
      cols_for_sint = svc.storable_columns.map { |c| c.name.to_s }
      all_sint_cols_exist = (cols_for_sint - existing_columns).empty?

      all_indexes_exist = svc.indexes(svc.dbadapter_table).all? do |ind|
        Webhookdb::Replicator.refers_to_any_same_index?(Sequel[svc.dbadapter_table.name][ind.name], indexes_in_org_db)
      end

      svc.ensure_all_columns unless all_sint_cols_exist && all_indexes_exist
      if svc.requires_sequence? && !sequences_in_app_db.include?(sint.sequence_name)
        sint.ensure_sequence(skip_check: true)
      end
    end
  end

  # Modify the admin and readonly users to have new usernames and passwords.
  def roll_database_credentials
    self.db.transaction do
      self.lock!
      builder = self.db_builder
      builder.roll_connection_credentials
      self.admin_connection_url_raw = builder.admin_url
      self.readonly_connection_url_raw = builder.readonly_url
      self.save_changes
    end
  end

  def migrate_replication_schema(schema)
    Webhookdb::DBAdapter.validate_identifier!(schema, type: "schema")
    Webhookdb::Organization::DatabaseMigration.guard_ongoing!(self)
    raise SchemaMigrationError, "destination and target schema are the same" if schema == self.replication_schema
    builder = self.db_builder
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

  def close(confirm:)
    raise Webhookdb::InvalidPrecondition, "confirm must be true to close the org" unless confirm
    unless self.service_integrations_dataset.empty?
      msg = "Organization[#{self.key} cannot close with active service integrations"
      raise Webhookdb::InvalidPrecondition, msg
    end
    memberships = self.all_memberships_dataset.all.each(&:destroy)
    self.destroy
    return [self, memberships]
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

  def available_replicators
    available = Webhookdb::Replicator.registry.values.filter do |desc|
      # The org must have any of the flags required for the service. In other words,
      # the intersection of desc[:feature_roles] & org.feature_roles must
      # not be empty
      no_restrictions = desc.feature_roles.empty?
      next true if no_restrictions
      org_has_access = (self.feature_roles.map(&:name) & desc.feature_roles).present?
      org_has_access
    end
    return available
  end

  #
  # :section: Validations
  #

  def validate
    super
    validates_all_or_none(:admin_connection_url_raw, :readonly_connection_url_raw, predicate: :present?)
    validates_format(/^\D/, :name, message: "can't begin with a digit")
    validates_format(/^[a-z][a-z0-9_]*$/, :key, message: "is not valid as a CNAME")
    validates_max_length 63, :key, message: "is not valid as a CNAME"
  end

  # @!attribute service_integrations
  #   @return [Array<Webhookdb::ServiceIntegration>]

  # @!attribute created_at
  #   @return [Time,nil]

  # @!attribute updated_at
  #   @return [Time,nil]

  # @!attribute soft_deleted_at
  #   @return [Time,nil]

  # @!attribute name
  #   @return [String]

  # @!attribute key
  #   @return [String]

  # @!attribute billing_email
  #   @return [String]

  # @!attribute stripe_customer_id
  #   @return [String]

  # @!attribute readonly_connection_url_raw
  #   @return [String]

  # @!attribute admin_connection_url_raw
  #   @return [String]

  # @!attribute public_host
  #   @return [String]

  # @!attribute cloudflare_dns_record_json
  #   @return [Hash]

  # @!attribute replication_schema
  #   @return [String]

  # @!attribute organization_job_semaphore_size
  #   @return [Integer]

  # @!attribute minimum_sync_seconds
  #   @return [Integer]

  # @!attribute sync_target_timeout
  #   @return [Integer]

  # @!attribute max_query_rows
  #   @return [Integer]

  # @!attribute priority_backfill
  #   @return [true,false]
end

require "webhookdb/organization/alerting"
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
#  minimum_sync_seconds        | integer                  | NOT NULL
#  sync_target_timeout         | integer                  | NOT NULL DEFAULT 30
#  max_query_rows              | integer                  |
#  priority_backfill           | boolean                  | NOT NULL DEFAULT false
#  text_search                 | tsvector                 |
# Indexes:
#  organizations_pkey     | PRIMARY KEY btree (id)
#  organizations_key_key  | UNIQUE btree (key)
#  organizations_name_key | UNIQUE btree (name)
# Referenced By:
#  feature_roles_organizations      | feature_roles_organizations_organization_id_fkey      | (organization_id) REFERENCES organizations(id)
#  logged_webhooks                  | logged_webhooks_organization_id_fkey                  | (organization_id) REFERENCES organizations(id) ON DELETE CASCADE
#  oauth_sessions                   | oauth_sessions_organization_id_fkey                   | (organization_id) REFERENCES organizations(id) ON DELETE CASCADE
#  organization_database_migrations | organization_database_migrations_organization_id_fkey | (organization_id) REFERENCES organizations(id) ON DELETE CASCADE
#  organization_memberships         | organization_memberships_organization_id_fkey         | (organization_id) REFERENCES organizations(id)
#  saved_queries                    | saved_queries_organization_id_fkey                    | (organization_id) REFERENCES organizations(id) ON DELETE CASCADE
#  saved_views                      | saved_views_organization_id_fkey                      | (organization_id) REFERENCES organizations(id) ON DELETE CASCADE
#  service_integrations             | service_integrations_organization_id_fkey             | (organization_id) REFERENCES organizations(id)
#  webhook_subscriptions            | webhook_subscriptions_organization_id_fkey            | (organization_id) REFERENCES organizations(id)
# ------------------------------------------------------------------------------------------------------------------------------------------------------------
