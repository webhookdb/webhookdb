# frozen_string_literal: true

require "webhookdb/theranest"
require "webhookdb/services/theranest_v1_mixin"

class Webhookdb::Services::TheranestProgressNoteDocumentV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::TheranestV1Mixin

  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "theranest_progress_note_document_v1",
      ctor: self,
      feature_roles: ["theranest"],
      resource_name_singular: "Theranest Progress Note Document",
      dependency_descriptor: Webhookdb::Services::TheranestProgressNoteV1.descriptor,
    )
  end

  def _webhook_verified?(_request)
    # Webhooks aren't supported
    return true
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:external_id, TEXT, data_key: "DocumentId")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:external_appointment_id, TEXT, data_key: "AppointmentId"),
      Webhookdb::Services::Column.new(:external_client_id, TEXT, data_key: "ClientId"),
      Webhookdb::Services::Column.new(:external_download_url, TEXT, data_key: "DownloadUrl"),
      Webhookdb::Services::Column.new(:external_is_staff_signed, BOOLEAN, data_key: "IsStaffSigned"),
      # We will populate this with a value from the Backfiller Class after preparation
      Webhookdb::Services::Column.new(:external_progress_note_id, TEXT, optional: true),
      Webhookdb::Services::Column.new(
        :external_staff_signed_at,
        TIMESTAMP,
        data_key: "StaffSignedOn",
        converter: CONV_PARSE_DATETIME,
      ),
      Webhookdb::Services::Column.new(:external_staff_signer_id, TEXT, data_key: "StaffSignerId"),
      # This does not exist in the resource, it is always getting set to `DateTime.now`
      Webhookdb::Services::Column.new(
        :updated_at,
        TIMESTAMP,
        data_key: "updated_at",
        optional: true,
        defaulter: :now,
      ),
      Webhookdb::Services::Column.new(:row_updated_at, TIMESTAMP, defaulter: :now, optional: true),
    ]
  end

  def _timestamp_column_name
    return :row_updated_at
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:data] !~ Sequel[:excluded][:data]
  end

  def _backfillers
    raise Webhookdb::Services::CredentialsMissing if self.theranest_auth_cookie.blank?

    progress_note_svc = self.service_integration.depends_on.service_instance
    backfillers = progress_note_svc.admin_dataset(timeout: :fast) do |progress_note_ds|
      progress_note_ds.select(:external_case_id, :external_id).map do |note|
        ProgressNoteDocumentBackfiller.new(
          progress_note_document_svc: self,
          theranest_case_id: note[:external_case_id],
          theranest_progress_note_id: note[:external_id],
        )
      end
    end

    return backfillers
  end

  class ProgressNoteDocumentBackfiller < Webhookdb::Backfiller
    def initialize(progress_note_document_svc:, theranest_case_id:, theranest_progress_note_id:)
      @progress_note_document_svc = progress_note_document_svc
      @theranest_case_id = theranest_case_id
      @theranest_progress_note_id = theranest_progress_note_id
      super()
    end

    def handle_item(body)
      body["external_progress_note_id"] = @theranest_progress_note_id
      @progress_note_document_svc.upsert_webhook_body(body)
    end

    def fetch_backfill_page(_pagination_token, **_kwargs)
      # In order to retrieve the document id for the detail view, we need to hit a separate endpoint first
      get_id_url = @progress_note_document_svc.theranest_api_url +
        "/api/sign/getNote?caseId=#{@theranest_case_id}&noteId=#{@theranest_progress_note_id}"
      id_response = Webhookdb::Http.get(
        get_id_url,
        headers: @progress_note_document_svc.theranest_auth_headers,
        logger: @progress_note_document_svc.logger,
      )
      document_id = id_response.parsed_response

      # Now that we have the document id, we can get the detail view
      url = @progress_note_document_svc.theranest_api_url + "/api/sign/getDocumentView/#{document_id}"
      response = Webhookdb::Http.get(
        url,
        headers: @progress_note_document_svc.theranest_auth_headers,
        logger: @progress_note_document_svc.logger,
      )
      data = [response.parsed_response]
      return data, nil
    end
  end
end
