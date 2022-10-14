# frozen_string_literal: true

require "webhookdb/theranest"
require "webhookdb/services/theranest_v1_mixin"

class Webhookdb::Services::TheranestProgressNoteV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::TheranestV1Mixin

  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "theranest_progress_note_v1",
      ctor: self,
      feature_roles: ["theranest"],
      resource_name_singular: "Theranest Progress Note",
      dependency_descriptor: Webhookdb::Services::TheranestCaseV1.descriptor,
    )
  end

  def _webhook_verified?(_request)
    # Webhooks aren't supported
    return true
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:external_id, TEXT, data_key: "NoteId")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:external_case_id, TEXT, data_key: "CaseId"),
      Webhookdb::Services::Column.new(:external_client_id, TEXT, data_key: "ClientId"),
      Webhookdb::Services::Column.new(
        :theranest_created_at,
        TIMESTAMP,
        optional: true, # Not actually optional but we hard-code the columns in the converter
        converter: Webhookdb::Services::Column::IsomorphicProc.new(
          ruby: lambda do |_, resource:, **|
                  s = resource.fetch("CreationDate") + " " + resource.fetch("CreationTime")
                  return Time.strptime(s, "%m/%d/%Y %H:%M %p")
                end,
          sql: lambda do |_e|
                 creation_str_expr = Sequel.function(
                   :concat,
                   Sequel.pg_json(:data).get_text("CreationDate"),
                   " ",
                   Sequel.pg_json(:data).get_text("CreationTime"),
                 )
                 Sequel.function(:to_timestamp,
                                 creation_str_expr,
                                 "MM/DD/YYYY HH24:MI AM",)
               end,
        ),
      ),
    ]
  end

  def _timestamp_column_name
    return :theranest_created_at
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:data] !~ Sequel[:excluded][:data]
  end

  def _backfillers
    raise Webhookdb::Services::CredentialsMissing if self.theranest_auth_cookie.blank?

    case_svc = self.service_integration.depends_on.service_instance
    backfillers = case_svc.readonly_dataset(timeout: :fast) do |case_ds|
      case_ds.exclude(state: "deleted").select(:external_id, :external_client_id).map do |theranest_case|
        ProgressNoteBackfiller.new(
          progress_note_svc: self,
          theranest_case_id: theranest_case[:external_id],
          theranest_client_id: theranest_case[:external_client_id],
        )
      end
    end
    return backfillers
  end

  class ProgressNoteBackfiller < Webhookdb::Backfiller
    def initialize(progress_note_svc:, theranest_client_id:, theranest_case_id:)
      @progress_note_svc = progress_note_svc
      @theranest_client_id = theranest_client_id
      @theranest_case_id = theranest_case_id
      super()
    end

    def handle_item(body)
      url = @progress_note_svc.theranest_api_url +
        "/api/cases/get-progress-note?" \
        "caseId=#{@theranest_case_id}&clientId=#{@theranest_client_id}&noteId=#{body.fetch('NoteId')}" \
        "&appointmentId=&templateId=" # You NEED this or you get a 404
      response = Webhookdb::Http.get(
        url,
        headers: @progress_note_svc.theranest_auth_headers,
        logger: @progress_note_svc.logger,
      )
      note_body = response.parsed_response
      @progress_note_svc.upsert_webhook_body(note_body)
    end

    def fetch_backfill_page(_pagination_token, **_kwargs)
      url = @progress_note_svc.theranest_api_url + "/api/cases/get-progress-notes-list?caseId=#{@theranest_case_id}"
      response = Webhookdb::Http.get(
        url,
        headers: @progress_note_svc.theranest_auth_headers,
        logger: @progress_note_svc.logger,
      )
      data = response.parsed_response["Notes"]
      return data, nil
    end
  end
end
