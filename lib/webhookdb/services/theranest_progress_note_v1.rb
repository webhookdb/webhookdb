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

  def calculate_create_state_machine
    # can inherit the `.ASPXAUTH` piece of the cookie and the API url from the auth dependency
    if (step = self.calculate_dependency_state_machine_step(dependency_help: ""))
      return step
    end
    step = Webhookdb::Services::StateMachineStep.new
    step.output = %(Great! If you have fully set up your Theranest Auth, Client, and Case integrations,
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
      Webhookdb::Services::Column.new(:external_case_id, TEXT),
      Webhookdb::Services::Column.new(:theranest_is_signed_by_staff, BOOLEAN),
      Webhookdb::Services::Column.new(:theranest_created_at, DATE),
    ]
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:data] !~ Sequel[:excluded][:data]
  end

  def backfill(cascade: false, **)
    auth_svc = self.find_auth_integration.service_instance
    auth_cookie = auth_svc.get_auth_cookie
    raise Webhookdb::Services::CredentialsMissing if auth_cookie.blank?

    case_svc = self.service_integration.depends_on.service_instance
    case_rows = case_svc.readonly_dataset { |ds| ds.exclude(state: "deleted") }
    case_rows.each do |theranest_case|
      backfiller = ProgressNoteBackfiller.new(
        progress_note_svc: self,
        theranest_case_id: theranest_case[:external_id],
        theranest_client_id: theranest_case[:external_client_id],
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

  class ProgressNoteBackfiller < Webhookdb::Backfiller
    def initialize(progress_note_svc:, theranest_client_id:, theranest_case_id:)
      @progress_note_svc = progress_note_svc
      @theranest_client_id = theranest_client_id
      @theranest_case_id = theranest_case_id
      @auth_sint = progress_note_svc.find_auth_integration
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
        external_id: body.fetch("NoteId"),
        external_client_id: @theranest_client_id,
        external_case_id: body.fetch("CaseId"),
        theranest_is_signed_by_staff: body.fetch("IsSignedByStaff"),
        theranest_created_at: parse_datetime(body.fetch("Date")),
      }
      upserted_rows = @progress_note_svc.admin_dataset do |ds|
        ds.insert_conflict(
          target: :external_id,
          update: inserting,
        ).insert(inserting)
      end
      row_changed = upserted_rows.present?
      @progress_note_svc._publish_rowupsert(inserting) if row_changed
    end

    def fetch_backfill_page(_pagination_token, **_kwargs)
      url = @api_url + "/api/cases/get-progress-notes-list?caseId=#{@theranest_case_id}"

      response = Webhookdb::Http.get(
        url,
        headers: @auth_svc.get_auth_headers,
        logger: @progress_note_svc.logger,
      )
      data = response.parsed_response["Notes"]
      return data, nil
    end
  end
end
