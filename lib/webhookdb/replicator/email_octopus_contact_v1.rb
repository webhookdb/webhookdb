# frozen_string_literal: true

require "webhookdb/email_octopus"

class Webhookdb::Replicator::EmailOctopusContactV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "email_octopus_contact_v1",
      ctor: ->(sint) { Webhookdb::Replicator::EmailOctopusContactV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "Email Octopus Contact",
      dependency_descriptor: Webhookdb::Replicator::EmailOctopusListV1.descriptor,
      supports_backfill: true,
    )
  end

  CONV_REMOTE_KEY = Webhookdb::Replicator::Column::IsomorphicProc.new(
    ruby: ->(_, resource:, **_) { "#{resource.fetch('id')}-#{resource.fetch('list_id')}" },
    # Because this is a non-nullable key, we never need this in SQL
    sql: ->(_) { Sequel.lit("'do not use'") },
  )

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(
      :compound_identity,
      TEXT,
      data_key: "<compound key, see converter>",
      index: true,
      optional: true,
      converter: CONV_REMOTE_KEY,
    )
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:email_octopus_id, TEXT, data_key: "id"),
      Webhookdb::Replicator::Column.new(:email_octopus_list_id, TEXT, data_key: "list_id"),
      Webhookdb::Replicator::Column.new(:email_address, TEXT),
      Webhookdb::Replicator::Column.new(:status, TEXT),
      Webhookdb::Replicator::Column.new(:created_at, TIMESTAMP, index: true, converter: :time, skip_nil: true),
      Webhookdb::Replicator::Column.new(:deleted_at, TIMESTAMP, converter: :time, optional: true),
      Webhookdb::Replicator::Column.new(:row_updated_at, TIMESTAMP, defaulter: :now, optional: true),
    ]
  end

  def _upsert_webhook(request, upsert: true)
    return super unless request.body.is_a?(Array)

    # If the body is an array, it means we are upserting data from webhooks, which has been passed to this function by
    # the event replicator, and we have to transform the data in order to be able to upsert.
    new_bodies = request.body.map do |wh|
      event_type = wh.fetch("type")

      {
        "id" => wh.fetch("contact_id"),
        "list_id" => wh.fetch("list_id"),
        "email_address" => wh.fetch("contact_email_address"),
        "status" => wh.fetch("contact_status"),
        "row_updated_at" => wh.fetch("occurred_at"),
        "created_at" => event_type == "contact.created" ? wh.fetch("occurred_at") : nil,
        "deleted_at" => event_type == "contact.deleted" ? wh.fetch("occurred_at") : nil,
        # These fields do not get denormalized but we still want the info to be present in the "data" field of the row.
        "fields" => wh["contact_fields"],
        "tags" => wh["contact_tags"],
      }
    end
    new_bodies.each do |b|
      new_request = request.dup
      new_request.body = b
      super(new_request, upsert:)
    end
  end

  def _resource_and_event(request)
    return request.body, nil
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:data] !~ Sequel[:excluded][:data]
  end

  def _timestamp_column_name
    return :row_updated_at
  end

  def _webhook_response(_request)
    return Webhookdb::WebhookResponse.ok
  end

  def calculate_backfill_state_machine
    if (step = self.calculate_dependency_state_machine_step(dependency_help: ""))
      return step
    end
    step = Webhookdb::Replicator::StateMachineStep.new
    # We're using the API Key from the dependency, we don't need to ask for it here
    step.output = %(Great! We are going to start replicating your #{self.resource_name_plural}.
#{self._query_help_output}
    )
    return step.completed
  end

  def on_dependency_webhook_upsert(_replicator, _payload, *)
    return
  end

  def _backfillers
    list_sint = self.service_integration.depends_on
    api_key = list_sint.replicator.backfill_key!
    backfillers = list_sint.replicator.admin_dataset(timeout: :fast) do |list_ds|
      list_ds.select(:email_octopus_id).map do |list|
        ContactBackfiller.new(
          contact_svc: self,
          list_id: list[:email_octopus_id],
          api_key:,
        )
      end
    end
    return backfillers
  end

  class ContactBackfiller < Webhookdb::Backfiller
    include Webhookdb::Backfiller::Bulk

    def initialize(contact_svc:, list_id:, api_key:)
      @contact_svc = contact_svc
      @list_id = list_id
      @api_key = api_key
      super()
    end

    def upserting_replicator = @contact_svc
    def upsert_page_size = 500

    def prepare_body(body)
      body["list_id"] = @list_id
    end

    def fetch_backfill_page(pagination_token, **_kwargs)
      limit = Webhookdb::EmailOctopus.page_size
      base_url = "https://emailoctopus.com"
      endpoint_path = pagination_token || "/api/1.6/lists/#{@list_id}/contacts?api_key=#{@api_key}&limit=#{limit}"
      response = Webhookdb::Http.get(
        base_url + endpoint_path,
        logger: @contact_svc.logger,
        timeout: Webhookdb::EmailOctopus.http_timeout,
      )
      data = response.parsed_response
      next_page_link = data.dig("paging", "next")
      return data["data"], next_page_link
    end
  end
end
