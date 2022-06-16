# frozen_string_literal: true

require "webhookdb/theranest"
require "webhookdb/services/theranest_v1_mixin"

class Webhookdb::Services::TheranestCaseV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::TheranestV1Mixin

  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "theranest_case_v1",
      ctor: self,
      feature_roles: ["theranest"],
      resource_name_singular: "Theranest Case",
      dependency_descriptor: Webhookdb::Services::TheranestClientV1.descriptor,
    )
  end

  def calculate_create_state_machine
    # can inherit the `.ASPXAUTH` piece of the cookie and the API url from the auth dependency
    if (step = self.calculate_dependency_state_machine_step(dependency_help: ""))
      return step
    end
    step = Webhookdb::Services::StateMachineStep.new
    step.output = %(Great! If you have fully set up your Theranest Auth and Theranest Client integrations,
you are all set.

#{self._query_help_output(prefix: "Once data is available, you can query #{self.resource_name_plural}.")})
    return step.completed
  end

  def _webhook_verified?(_request)
    # Webhooks aren't supported
    return true
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:external_id, TEXT)
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:external_client_id, TEXT),
      Webhookdb::Services::Column.new(:state, TEXT),
      Webhookdb::Services::Column.new(:theranest_created_at, DATE),
      Webhookdb::Services::Column.new(:theranest_status, TEXT),
      Webhookdb::Services::Column.new(:theranest_service_type_formatted_name, TEXT),
      Webhookdb::Services::Column.new(:theranest_deleted_at, DATE),
      Webhookdb::Services::Column.new(:theranest_deleted_by_name, TEXT),
    ]
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:data] !~ Sequel[:excluded][:data]
  end

  def backfill(cascade: false, **)
    auth_svc = self.find_auth_integration.service_instance
    auth_cookie = auth_svc.get_auth_cookie
    raise Webhookdb::Services::CredentialsMissing if auth_cookie.blank?

    client_svc = self.service_integration.depends_on.service_instance
    client_rows = client_svc.readonly_dataset { |ds| ds.exclude(archived_in_theranest: true) }
    client_rows.each do |client|
      backfiller = CaseBackfiller.new(
        case_svc: self,
        theranest_client_id: client[:theranest_id],
      )
      backfiller.backfill(nil)
    end

    return unless cascade
    self.service_integration.dependents.each do |dep|
      Webhookdb.publish(
        "webhookdb.serviceintegration.backfill", dep.id, {cascade: true},
      )
    end
  end

  class CaseBackfiller < Webhookdb::Backfiller
    def initialize(case_svc:, theranest_client_id:)
      @case_svc = case_svc
      @theranest_client_id = theranest_client_id
      @auth_sint = case_svc.find_auth_integration
      @auth_svc = @auth_sint.service_instance
      @api_url = @auth_sint.api_url
      super()
    end

    def parse_mdy_date(date)
      return Date.strptime(date, "%m/%d/%Y")
    rescue TypeError
      return nil
    end

    def handle_item(body)
      # what gets enacted on each item of each page
      state = if body.fetch("DeletedDate").present?
                "deleted"
              elsif body.fetch("Status").present?
                body.fetch("Status").downcase
              else
                ""
              end
      # TODO: Add rest of columns, even the ones whose info can't be retrieved from the API,
      # for the sake of fully matching the existing DB schema?
      inserting = {
        data: body.to_json,
        external_id: body.fetch("CaseId"),
        external_client_id: @theranest_client_id,
        state:,
        theranest_created_at: parse_mdy_date(body.fetch("Date")),
        theranest_status: body.fetch("Status"),
        theranest_service_type_formatted_name: body.fetch("ServiceType"),
        theranest_deleted_at: parse_mdy_date(body.fetch("DeletedDate")),
        theranest_deleted_by_name: body.fetch("DeletedByName"),
      }
      upserted_rows = @case_svc.admin_dataset do |ds|
        ds.insert_conflict(
          target: :external_id,
          update: inserting,
        ).insert(inserting)
      end
      row_changed = upserted_rows.present?
      @case_svc._publish_rowupsert(inserting) if row_changed
    end

    def fetch_backfill_page(_pagination_token, **_kwargs)
      url = @api_url + "/api/cases/getClientCases?clientId=#{@theranest_client_id}"

      response = Webhookdb::Http.get(
        url,
        headers: @auth_svc.get_auth_headers,
        logger: @case_svc.logger,
      )
      open_cases = response.parsed_response["OpenCases"]
      closed_cases = response.parsed_response["ClosedCases"]
      deleted_cases = response.parsed_response["DeletedCases"]
      data = open_cases + closed_cases + deleted_cases
      return data, nil
    end
  end
end
