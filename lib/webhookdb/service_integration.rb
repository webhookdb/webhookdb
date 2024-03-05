# frozen_string_literal: true

require "webhookdb/formatting"
require "webhookdb/id"
require "webhookdb/postgres/model"
require "sequel/plugins/soft_deletes"

class Webhookdb::ServiceIntegration < Webhookdb::Postgres::Model(:service_integrations)
  class TableRenameError < Webhookdb::InvalidInput; end

  # We limit the information that a user can access through the CLI to these fields.
  INTEGRATION_INFO_FIELDS = {
    "id" => :opaque_id,
    "service" => :service_name,
    "table" => :table_name,
    "url" => :unauthed_webhook_endpoint,
    "webhook_secret" => :webhook_secret,
    "webhookdb_api_key" => :webhookdb_api_key,
    "api_url" => :api_url,
  }.freeze

  plugin :timestamps
  plugin :text_searchable, terms: [:service_name, :table_name, :organization]
  plugin :column_encryption do |enc|
    enc.column :data_encryption_secret
    enc.column :webhook_secret
    enc.column :backfill_key
    enc.column :backfill_secret
    enc.column :webhookdb_api_key, searchable: true
  end

  many_to_one :organization, class: "Webhookdb::Organization"
  one_to_many :webhook_subscriptions, class: "Webhookdb::WebhookSubscription"
  one_to_many :all_webhook_subscriptions,
              class: "Webhookdb::WebhookSubscription",
              readonly: true,
              dataset: (
                lambda do |r|
                  r.associated_dataset.where(
                    Sequel[organization_id:] | Sequel[service_integration_id: id],
                  )
                end),
              eager_loader: (
                lambda do |eo|
                  sint_ids = eo[:id_map].keys
                  org_ids_for_sints = eo[:rows].to_h { |r| [r.id, r.organization_id] }
                  all_subs = Webhookdb::WebhookSubscription.
                    left_join(:service_integrations, {id: :service_integration_id}).
                    select(Sequel[:webhook_subscriptions][Sequel.lit("*")]).
                    where(
                      Sequel[Sequel[:webhook_subscriptions][:organization_id] => org_ids_for_sints.values.uniq] |
                        Sequel[Sequel[:webhook_subscriptions][:service_integration_id] => sint_ids],
                    ).all
                  subs_by_sint = {}
                  subs_by_org = {}
                  all_subs.each do |sub|
                    if (orgid = sub[:organization_id])
                      subs = subs_by_org[orgid] ||= []
                    else
                      sint_id = sub[:service_integration_id]
                      subs = subs_by_sint[sint_id] ||= []
                    end
                    subs << sub
                  end
                  eo[:rows].each do |sint|
                    subs = subs_by_sint.fetch(sint.id, [])
                    subs.concat(subs_by_org.fetch(sint.organization_id, []))
                    sint.associations[:all_webhook_subscriptions] = subs
                  end
                end)

  many_to_one :depends_on, class: self
  one_to_many :dependents, key: :depends_on_id, class: self
  one_to_many :sync_targets, class: "Webhookdb::SyncTarget"

  # @return [Webhookdb::ServiceIntegration]
  def self.create_disambiguated(service_name, **kwargs)
    kwargs[:table_name] ||= "#{service_name}_#{SecureRandom.hex(2)}"
    return self.create(service_name:, **kwargs)
  end

  # @return [Webhookdb::ServiceIntegration]
  def self.for_api_key(key)
    return self.with_encrypted_value(:webhookdb_api_key, key).first
  end

  def can_be_modified_by?(customer)
    return customer.verified_member_of?(self.organization)
  end

  # @return [Webhookdb::Replicator::Base]
  def replicator
    return Webhookdb::Replicator.create(self)
  end

  def log_tags
    return {
      service_integration_id: self.id,
      service_integration_name: self.service_name,
      service_integration_table: self.table_name,
      **self.organization.log_tags,
    }
  end

  def authed_api_path
    return "/v1/organizations/#{self.organization_id}/service_integrations/#{self.opaque_id}"
  end

  def unauthed_webhook_path
    return "/v1/service_integrations/#{self.opaque_id}"
  end

  def unauthed_webhook_endpoint
    return Webhookdb.api_url + self.unauthed_webhook_path
  end

  def plan_supports_integration?
    # if the sint's organization has an active subscription, return true
    return true if self.organization.active_subscription?
    # if there is no active subscription, check whether the integration is one of the first two
    # created by the organization
    limit = Webhookdb::Subscription.max_free_integrations
    free_integrations = Webhookdb::ServiceIntegration.
      where(organization: self.organization).order(:created_at, :id).limit(limit).all
    free_integrations.each do |sint|
      return true if sint.id == self.id
    end
    # if not, the integration is not supported
    return false
  end

  # Return service integrations that can be used as the dependency
  # for this integration.
  # @return [Array<Webhookdb::ServiceIntegration>]
  def dependency_candidates
    dep_descr = self.replicator.descriptor.dependency_descriptor
    return [] if dep_descr.nil?
    return self.organization.service_integrations.
        select { |si| si.service_name == dep_descr.name }
  end

  def recursive_dependents
    return self.dependents + self.dependents.flat_map(&:recursive_dependents)
  end

  def destroy_self_and_all_dependents
    self.dependents.each(&:destroy_self_and_all_dependents)

    if self.organization.admin_connection_url.present?
      begin
        self.replicator.admin_dataset(timeout: :fast) { |ds| ds.db << "DROP TABLE #{self.table_name}" }
      rescue Sequel::DatabaseError => e
        raise e unless e.wrapped_exception.is_a?(PG::UndefinedTable)
      end
    end
    self.destroy
  end

  class Stats
    attr_reader :message, :data

    def initialize(message, data)
      @message = message
      @data = data
    end

    def display_headers
      return [
        [:count_last_7_days_formatted, "Count Last 7 Days"],
        [:success_last_7_days_formatted, "Successful Last 7 Days"],
        [:success_last_7_days_percent_formatted, "Successful Last 7 Days %"],
        [:rejected_last_7_days_formatted, "Rejected Last 7 Days"],
        [:rejected_last_7_days_percent_formatted, "Rejected Last 7 Days %"],
        [:successful_of_last_10_formatted, "Successful Of Last 10 Webhooks"],
        [:rejected_of_last_10_formatted, "Rejected Of Last 10 Webhooks"],
      ]
    end

    def as_json(*_o)
      return @data.merge(message: @message, display_headers: self.display_headers)
    end
  end

  # @return [Webhookdb::ServiceIntegration::Stats]
  def stats
    all_logged_webhooks = Webhookdb::LoggedWebhook.where(
      service_integration_opaque_id: self.opaque_id,
    ).where { inserted_at > 7.days.ago }

    if all_logged_webhooks.empty?
      return Stats.new(
        "We have no record of receiving webhooks for that integration in the past seven days.",
        {},
      )
    end

    # rubocop:disable Naming/VariableNumber
    count_last_7_days = all_logged_webhooks.count
    rejected_last_7_days = all_logged_webhooks.where { response_status >= 400 }.count
    success_last_7_days = (count_last_7_days - rejected_last_7_days)
    rejected_last_7_days_percent = (rejected_last_7_days.to_f / count_last_7_days)
    success_last_7_days_percent = (success_last_7_days.to_f / count_last_7_days)
    last_10 = Webhookdb::LoggedWebhook.order_by(Sequel.desc(:inserted_at)).limit(10).select_map(:response_status)
    last_10_success, last_10_rejected = last_10.partition { |rs| rs < 400 }

    data = {
      count_last_7_days:,
      count_last_7_days_formatted: count_last_7_days.to_s,
      success_last_7_days:,
      success_last_7_days_formatted: success_last_7_days.to_s,
      success_last_7_days_percent:,
      success_last_7_days_percent_formatted: "%.1f%%" % (success_last_7_days_percent * 100),
      rejected_last_7_days:,
      rejected_last_7_days_formatted: rejected_last_7_days.to_s,
      rejected_last_7_days_percent:,
      rejected_last_7_days_percent_formatted: "%.1f%%" % (rejected_last_7_days_percent * 100),
      successful_of_last_10: last_10_success.size,
      successful_of_last_10_formatted: last_10_success.size.to_s,
      rejected_of_last_10: last_10_rejected.size,
      rejected_of_last_10_formatted: last_10_rejected.size.to_s,
    }
    # rubocop:enable Naming/VariableNumber
    return Stats.new("", data)
  end

  def rename_table(to:)
    Webhookdb::Organization::DatabaseMigration.guard_ongoing!(self.organization)
    Webhookdb::DBAdapter.validate_identifier!(to, type: "table")
    self.db.transaction do
      begin
        self.organization.admin_connection { |db| db << "ALTER TABLE #{self.table_name} RENAME TO #{to}" }
      rescue Sequel::DatabaseError => e
        case e.wrapped_exception
          when PG::DuplicateTable
            raise TableRenameError,
                  "There is already a table named \"#{to}\". Run `webhookdb db tables` to see available tables."
          when PG::SyntaxError
            raise TableRenameError,
                  "Please try again with double quotes around '#{to}' since it contains invalid identifier characters."
          else
            raise e
        end
      end
      self.update(table_name: to)
    end
  end

  def requires_sequence?
    return self.replicator.requires_sequence?
  end

  def sequence_name
    return "replicator_seq_org_#{self.organization_id}_#{self.service_name}_#{self.id}_seq"
  end

  def ensure_sequence(skip_check: false)
    self.db << self.ensure_sequence_sql(skip_check:)
  end

  def ensure_sequence_sql(skip_check: false)
    raise Webhookdb::InvalidPrecondition, "#{self.service_name} does not require sequence" if
      !skip_check && !self.requires_sequence?
    return "CREATE SEQUENCE IF NOT EXISTS #{self.sequence_name}"
  end

  def sequence_nextval
    return self.db.select(Sequel.function(:nextval, self.sequence_name)).single_value
  end

  def new_opaque_id = Webhookdb::Id.new_opaque_id("svi")

  def ensure_opaque_id = self[:opaque_id] ||= self.new_opaque_id

  def new_api_key
    k = +"sk/"
    k << self.ensure_opaque_id
    k << "/"
    k << Webhookdb::Id.rand_enc(24)
    return k
  end

  #
  # :Sequel Hooks:
  #

  def before_create
    self.ensure_opaque_id
  end

  # @!attribute organization
  #   @return [Webhookdb::Organization]

  # @!attribute table_name
  #   @return [String] Name of the table

  # @!attribute service_name
  #   @return [String] Lookup name of the service

  # @!attribute opaque_id
  #   @return [String]

  # @!attribute api_url
  #   @return [String] Root Url of the api to backfill from

  # @!attribute backfill_key
  #   @return [String] Key for backfilling.

  # @!attribute backfill_secret
  #   @return [String] Password/secret for backfilling.

  # @!attribute webhook_secret
  #   @return [String] Secret used to sign webhooks.

  # @!attribute webhookdb_api_key
  #   @return [String] API Key used in the Whdb-Api-Key header that can be used to identify
  #     this service integration (where the opaque id cannot be used),
  #     and is a secret so can be used for authentication.
  #     Need for this should be rare- it's usually only used outside of the core webhookdb/backfill design
  #     like for two-way sync (Front Channel/Signalwire integration, for example).

  # @!attribute depends_on
  #   @return [Webhookdb::ServiceIntegration]

  # @!attribute data_encryption_secret
  #   @return [String] The encryption key used to encrypt data for this organization.
  #                    Note that this field is itself encrypted using Sequel encryption;
  #                    its decrypted value is meant to be used as the data encryption key.

  # @!attribute skip_webhook_verification
  #   @return [Boolean] Set this to disable webhook verification on this integration.
  #                     Useful when replaying logged webhooks.
end

# Table: service_integrations
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Columns:
#  id                        | integer                  | PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY
#  created_at                | timestamp with time zone | NOT NULL DEFAULT now()
#  updated_at                | timestamp with time zone |
#  organization_id           | integer                  | NOT NULL
#  api_url                   | text                     | NOT NULL DEFAULT ''::text
#  opaque_id                 | text                     | NOT NULL
#  service_name              | text                     | NOT NULL
#  webhook_secret            | text                     |
#  table_name                | text                     | NOT NULL
#  backfill_key              | text                     |
#  backfill_secret           | text                     |
#  last_backfilled_at        | timestamp with time zone |
#  depends_on_id             | integer                  |
#  data_encryption_secret    | text                     |
#  skip_webhook_verification | boolean                  | NOT NULL DEFAULT false
#  webhookdb_api_key         | text                     |
#  text_search               | tsvector                 |
# Indexes:
#  service_integrations_pkey          | PRIMARY KEY btree (id)
#  service_integrations_opaque_id_key | UNIQUE btree (opaque_id)
#  unique_tablename_in_org            | UNIQUE btree (organization_id, table_name)
# Foreign key constraints:
#  service_integrations_depends_on_id_fkey   | (depends_on_id) REFERENCES service_integrations(id) ON DELETE RESTRICT
#  service_integrations_organization_id_fkey | (organization_id) REFERENCES organizations(id)
# Referenced By:
#  backfill_jobs                          | backfill_jobs_service_integration_id_fkey                       | (service_integration_id) REFERENCES service_integrations(id) ON DELETE CASCADE
#  backfill_job_service_integration_locks | backfill_job_service_integration_lo_service_integration_id_fkey | (service_integration_id) REFERENCES service_integrations(id) ON DELETE CASCADE
#  service_integrations                   | service_integrations_depends_on_id_fkey                         | (depends_on_id) REFERENCES service_integrations(id) ON DELETE RESTRICT
#  sync_targets                           | sync_targets_service_integration_id_fkey                        | (service_integration_id) REFERENCES service_integrations(id) ON DELETE CASCADE
#  webhook_subscriptions                  | webhook_subscriptions_service_integration_id_fkey               | (service_integration_id) REFERENCES service_integrations(id)
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
