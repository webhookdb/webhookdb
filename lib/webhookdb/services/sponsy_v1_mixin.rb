# frozen_string_literal: true

require "webhookdb/sponsy"

module Webhookdb::Services::SponsyV1Mixin
  include Webhookdb::DBAdapter::ColumnTypes

  def _remote_key_column
    return Webhookdb::Services::Column.new(:sponsy_id, TEXT, data_key: "id")
  end

  def _timestamp_column_name
    return :updated_at
  end

  def _ts_columns
    return [
      Webhookdb::Services::Column.new(:created_at, TIMESTAMP, data_key: "createdAt"),
      Webhookdb::Services::Column.new(
        :updated_at, TIMESTAMP,
        data_key: "updatedAt",
        defaulter: Webhookdb::Services::Column::DEFAULTER_FROM_CREATED_AT,
      ),
    ]
  end

  def _verify_backfill_err_msg
    return "Looks like your API key is invalid."
  end

  def api_url
    return "https://api.getsponsy.com"
  end

  def auth_headers
    return {"X-Api-Key" => self.find_api_key}
  end

  def find_api_key
    return @apikey if @apikey
    checking_sint = self.service_integration
    10.times do
      if checking_sint.backfill_secret.present?
        @apikey = checking_sint.backfill_secret
        return @apikey
      end
      checking_sint = checking_sint.depends_on
      break if checking_sint.nil?
    end
    raise Webhookdb::Services::CredentialsMissing, "This Sponsy integration is missing its dependency"
  end

  def _resource_and_event(body)
    return body, nil
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:updated_at] < Sequel[:excluded][:updated_at]
  end

  def _webhook_response(_request)
    # There are no webhooks to respond to, these are backfill-only integrations
    return Webhookdb::WebhookResponse.ok
  end

  # @return [Webhookdb::Services::StateMachineStep]
  def calculate_create_state_machine
    raise Webhookdb::InvalidPrecondition, "#{self} has no dependency so should override this method" unless
      self.class.descriptor.dependency_descriptor
    if (step = self.calculate_dependency_state_machine_step(dependency_help: ""))
      return step
    end
    step = Webhookdb::Services::StateMachineStep.new
    step.output = %(Great! You are all set.

#{self._query_help_output(prefix: "Once data is available, you can query #{self.resource_name_plural}.")})
    return step.completed
  end

  # @return [Webhookdb::Services::StateMachineStep]
  def calculate_backfill_state_machine
    step = Webhookdb::Services::StateMachineStep.new
    step.output = %(We will start backfilling #{self.resource_name_plural} into your WebhookDB database.

#{self._query_help_output(prefix: "Once data is available, you can query #{self.resource_name_plural}.")})
    return step.completed
  end

  def on_dependency_webhook_upsert(_service_instance, _payload, *)
    return
  end

  # Paginate from most recently updated.
  # We paginate until either:
  # - There are no more pages (the 'after cursor' is nil), or
  # - the updated at timestamp predates the time we last backfilled,
  #   meaning we probably already saw this update.
  def fetch_sponsy_page(tail, pagination_token, last_backfilled)
    url = self.api_url + tail
    response = Webhookdb::Http.get(
      url,
      query: {
        limit: Webhookdb::Sponsy.page_size.to_s,
        afterCursor: pagination_token,
        orderBy: "updatedAt",
        orderDirection: "DESC",
      },
      headers: self.auth_headers,
      logger: self.logger,
    )
    data = response.parsed_response.fetch("data")
    after_cursor = response.parsed_response.fetch("cursor").fetch("afterCursor", nil)
    return data, nil if after_cursor.nil?
    return [], nil if data.empty?
    last_updated = data.last.fetch("updatedAt")
    return data, nil if last_updated < (last_backfilled || Time.at(0))
    return data, after_cursor
  end

  def _publication_backfillers(tail)
    raise Webhookdb::Services::CredentialsMissing if self.find_api_key.blank?

    publications_svc = self.service_integration.depends_on.service_instance
    backfillers = publications_svc.readonly_dataset(timeout: :fast) do |pub_ds|
      pub_ds.select(:sponsy_id).map do |publication|
        PublicationChildBackfiller.new(
          service: self,
          publication_id: publication.fetch(:sponsy_id),
          tail:,
        )
      end
    end
    return backfillers
  end

  class PublicationChildBackfiller < Webhookdb::Backfiller
    def initialize(service:, publication_id:, tail:)
      @service = service
      @publication_id = publication_id
      @tail = tail
      super()
    end

    def handle_item(body)
      body["publication_id"] = @publication_id
      @service.upsert_webhook_body(body)
    end

    def fetch_backfill_page(pagination_token, last_backfilled:)
      return @service.fetch_sponsy_page(
        "/v1/publications/#{@publication_id}#{@tail}", pagination_token, last_backfilled,
      )
    end
  end
end
