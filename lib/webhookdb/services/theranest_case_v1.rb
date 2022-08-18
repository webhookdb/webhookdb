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

  def _timestamp_column_name
    return :row_updated_at
  end

  def _webhook_verified?(_request)
    # Webhooks aren't supported
    return true
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:external_id, TEXT, data_key: "CaseId")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:external_client_id, TEXT),
      Webhookdb::Services::Column.new(:row_updated_at, TIMESTAMP, defaulter: :now, optional: true),
      Webhookdb::Services::Column.new(:state, TEXT),
      Webhookdb::Services::Column.new(
        :theranest_created_at,
        DATE,
        data_key: "Date",
        converter: CONV_PARSE_MDY_SLASH,
      ),
      Webhookdb::Services::Column.new(
        :theranest_deleted_at,
        DATE,
        data_key: "DeletedDate",
        converter: CONV_PARSE_MDY_SLASH,
      ),
      Webhookdb::Services::Column.new(:theranest_deleted_by_name, TEXT, data_key: "DeletedByName"),
      Webhookdb::Services::Column.new(:theranest_service_type_formatted_name, TEXT, data_key: "ServiceType"),
      Webhookdb::Services::Column.new(:theranest_status, TEXT, data_key: "Status"),
    ]
  end

  def _backfillers
    raise Webhookdb::Services::CredentialsMissing if self.theranest_auth_cookie.blank?

    client_svc = self.service_integration.depends_on.service_instance
    backfillers = client_svc.admin_dataset(timeout: :fast) do |client_ds|
      client_ds.exclude(archived_in_theranest: true).select(:theranest_id).map do |client|
        CaseBackfiller.new(
          case_svc: self,
          theranest_client_id: client[:theranest_id],
        )
      end
    end
    return backfillers
  end

  class CaseBackfiller < Webhookdb::Backfiller
    def initialize(case_svc:, theranest_client_id:)
      @case_svc = case_svc
      @theranest_client_id = theranest_client_id
      super()
    end

    def handle_item(body)
      state = if body.fetch("DeletedDate").present?
                "deleted"
              elsif body.fetch("Status").present?
                body.fetch("Status").downcase
              else
                ""
              end
      body["external_client_id"] = @theranest_client_id
      body["state"] = state
      @case_svc.upsert_webhook(body:)
    end

    def fetch_backfill_page(_pagination_token, **_kwargs)
      url = @case_svc.theranest_api_url + "/api/cases/getClientCases?clientId=#{@theranest_client_id}"

      response = Webhookdb::Http.get(
        url,
        headers: @case_svc.theranest_auth_headers,
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
