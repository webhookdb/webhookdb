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

  def calculate_create_state_machine
    # can inherit the `.ASPXAUTH` piece of the cookie and the API url from the auth dependency
    if (step = self.calculate_dependency_state_machine_step(dependency_help: ""))
      return step
    end
    step = Webhookdb::Services::StateMachineStep.new
    step.output = %(Great! If you have fully set up your Theranest Auth, Client, Case, and Progress Note integrations,
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
      Webhookdb::Services::Column.new(:external_appointment_id, TEXT),
      Webhookdb::Services::Column.new(:external_client_id, TEXT),
      Webhookdb::Services::Column.new(:external_download_url, TEXT),
      Webhookdb::Services::Column.new(:external_is_staff_signed, BOOLEAN),
      Webhookdb::Services::Column.new(:external_progress_note_id, TEXT),
      Webhookdb::Services::Column.new(:external_staff_signed_at, TIMESTAMP),
      Webhookdb::Services::Column.new(:external_staff_signer_id, TEXT),
      Webhookdb::Services::Column.new(:updated_at, TIMESTAMP),
    ]
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:data] !~ Sequel[:excluded][:data]
  end

  def backfill(cascade: false, **)
    auth_svc = self.find_auth_integration.service_instance
    auth_cookie = auth_svc.get_auth_cookie
    raise Webhookdb::Services::CredentialsMissing if auth_cookie.blank?

    progress_note_svc = self.service_integration.depends_on.service_instance
    progress_note_rows = progress_note_svc.readonly_dataset(&:all)
    progress_note_rows.each do |note|
      backfiller = ProgressNoteDocumentBackfiller.new(
        progress_note_document_svc: self,
        theranest_case_id: note[:external_case_id],
        theranest_progress_note_id: note[:external_id],
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

  class ProgressNoteDocumentBackfiller < Webhookdb::Backfiller
    def initialize(progress_note_document_svc:, theranest_case_id:, theranest_progress_note_id:)
      @progress_note_document_svc = progress_note_document_svc
      @theranest_case_id = theranest_case_id
      @theranest_progress_note_id = theranest_progress_note_id
      @auth_sint = progress_note_document_svc.find_auth_integration
      @auth_svc = @auth_sint.service_instance
      @api_url = @auth_sint.api_url
      super()
    end

    def parse_datetime(date)
      return Date.strptime(date, "%m/%d/%Y %H:%M %p")
    rescue TypeError
      return nil
    end

    def handle_item(body)
      # what gets enacted on each item of each page
      inserting = {
        data: body.to_json,
        external_id: body.fetch("DocumentId"),
        external_appointment_id: body.fetch("AppointmentId"),
        external_client_id: body.fetch("ClientId"),
        external_download_url: body.fetch("DownloadUrl"),
        external_is_staff_signed: body.fetch("IsStaffSigned"),
        external_progress_note_id: @theranest_progress_note_id,
        external_staff_signed_at: parse_datetime(body.fetch("StaffSignedOn")),
        external_staff_signer_id: body.fetch("StaffSignerId"),
        updated_at: DateTime.now,
      }
      upserted_rows = @progress_note_document_svc.admin_dataset do |ds|
        ds.insert_conflict(
          target: :external_id,
          update: inserting,
        ).insert(inserting)
      end
      row_changed = upserted_rows.present?
      @progress_note_document_svc._publish_rowupsert(inserting) if row_changed
    end

    def fetch_backfill_page(_pagination_token, **_kwargs)
      # In order to retrieve the document id for the detail view, we need to hit a separate endpoint first
      get_id_url = @api_url + "/api/sign/getNote?caseId=#{@theranest_case_id}&noteId=#{@theranest_progress_note_id}"
      id_response = Webhookdb::Http.get(
        get_id_url,
        headers: @auth_svc.get_auth_headers,
        logger: @progress_note_document_svc.logger,
      )
      document_id = id_response.parsed_response

      # Now that we have the document id, we can get the detail view
      url = @api_url + "/api/sign/getDocumentView/#{document_id}"
      response = Webhookdb::Http.get(
        url,
        headers: @auth_svc.get_auth_headers,
        logger: @progress_note_document_svc.logger,
      )
      data = [response.parsed_response]
      return data, nil
    end
  end
end
