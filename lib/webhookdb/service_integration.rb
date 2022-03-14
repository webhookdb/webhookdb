# frozen_string_literal: true

require "webhookdb/formatting"
require "webhookdb/id"
require "webhookdb/postgres/model"
require "sequel/plugins/soft_deletes"

class Webhookdb::ServiceIntegration < Webhookdb::Postgres::Model(:service_integrations)
  plugin :timestamps
  plugin :soft_deletes

  many_to_one :organization, class: "Webhookdb::Organization"
  one_to_many :webhook_subscriptions, class: "Webhookdb::WebhookSubscription"
  one_to_many :all_webhook_subscriptions,
              class: "Webhookdb::WebhookSubscription",
              readonly: true do |ds|
    ds.or(Sequel[organization_id: :organization_id])
  end

  def process_state_change(field, value)
    return Webhookdb::Services.service_instance(self).process_state_change(field, value)
  end

  def calculate_create_state_machine
    return Webhookdb::Services.service_instance(self).calculate_create_state_machine
  end

  def calculate_backfill_state_machine
    return Webhookdb::Services.service_instance(self).calculate_backfill_state_machine
  end

  def can_be_modified_by?(customer)
    return customer.verified_member_of?(self.organization)
  end

  def service_instance
    return Webhookdb::Services.service_instance(self)
  end

  def authed_api_path
    return "/v1/organizations/#{self.organization_id}/service_integrations/#{self.opaque_id}"
  end

  def unauthed_webhook_path
    return "/v1/service_integrations/#{self.opaque_id}"
  end

  # SUBSCRIPTION PERMISSIONS

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

  def stats(format)
    Webhookdb::Formatting.validate!(format)
    all_logged_webhooks = Webhookdb::LoggedWebhook.where(
      service_integration_opaque_id: self.opaque_id,
    ).where { inserted_at > 7.days.ago }

    no_logged_webhooks_msg = "We have no record of receiving webhooks for that integration in the past seven days."

    if all_logged_webhooks.empty?
      if format == "table"
        return {
          headers: ["Message"],
          rows: [[no_logged_webhooks_msg]],
        }
      end
      return {message: no_logged_webhooks_msg}
    end

    # rubocop:disable Naming/VariableNumber
    count_last_7_days = all_logged_webhooks.count
    rejected_last_7_days = all_logged_webhooks.where { response_status >= 400 }.count
    success_last_7_days = (count_last_7_days - rejected_last_7_days)
    rejected_last_7_days_percent = (rejected_last_7_days.to_f / count_last_7_days)
    success_last_7_days_percent = (success_last_7_days.to_f / count_last_7_days)
    last_10 = Webhookdb::LoggedWebhook.order_by(Sequel.desc(:inserted_at)).limit(10).select_map(:response_status)
    last_10_success, last_10_rejected = last_10.partition { |rs| rs < 400 }

    # this "table" format is designed to make formatting the CLI output easier by returning data
    # in the form that our Go table formatting library requires
    if format == Webhookdb::Formatting::TABLE
      return {
        headers: ["name", "value"],
        rows: [
          ["Count Last 7 Days", count_last_7_days.to_s],
          ["Successful Last 7 Days", success_last_7_days.to_s],
          ["Successful Last 7 Days (Percent)", "%.1f%%" % (success_last_7_days_percent * 100)],
          ["Rejected Last 7 Days", rejected_last_7_days.to_s],
          ["Rejected Last 7 Days (Percent)", "%.1f%%" % (rejected_last_7_days_percent * 100)],
          ["Successful Of Last 10 Webhooks", last_10_success.size.to_s],
          ["Rejected Of Last 10 Webhooks", last_10_rejected.size.to_s],
        ],
      }
    end

    return {
      count_last_7_days:,
      success_last_7_days:,
      success_last_7_days_percent:,
      rejected_last_7_days:,
      rejected_last_7_days_percent:,
      successful_of_last_10: last_10_success.size,
      rejected_of_last_10: last_10_rejected.size,
    }
    # rubocop:enable Naming/VariableNumber
  end

  #
  # :Sequel Hooks:
  #

  def before_create
    self[:opaque_id] ||= Webhookdb::Id.new_opaque_id("svi")
  end

  # @!attribute table_name
  #   @return [String] Name of the table

  # @!attribute service_name
  #   @return [String] Lookup name of the service

  # @!attribute api_url
  #   @return [String] Root Url of the api to backfill from

  # @!attribute backfill_key
  #   @return [String] Key for backfilling.

  # @!attribute backfill_secret
  #   @return [String] Password/secret for backfilling.
end

# Table: service_integrations
# ---------------------------------------------------------------------------------------------
# Columns:
#  id                 | integer                  | PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY
#  created_at         | timestamp with time zone | NOT NULL DEFAULT now()
#  updated_at         | timestamp with time zone |
#  soft_deleted_at    | timestamp with time zone |
#  organization_id    | integer                  | NOT NULL
#  api_url            | text                     | NOT NULL DEFAULT ''::text
#  opaque_id          | text                     | NOT NULL
#  service_name       | text                     | NOT NULL
#  webhook_secret     | text                     | DEFAULT ''::text
#  table_name         | text                     | NOT NULL
#  backfill_key       | text                     | NOT NULL DEFAULT ''::text
#  backfill_secret    | text                     | NOT NULL DEFAULT ''::text
#  last_backfilled_at | timestamp with time zone |
# Indexes:
#  service_integrations_pkey          | PRIMARY KEY btree (id)
#  service_integrations_opaque_id_key | UNIQUE btree (opaque_id)
#  unique_tablename_in_org            | UNIQUE btree (organization_id, table_name)
# Foreign key constraints:
#  service_integrations_organization_id_fkey | (organization_id) REFERENCES organizations(id)
# ---------------------------------------------------------------------------------------------
