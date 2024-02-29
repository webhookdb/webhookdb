# frozen_string_literal: true

require "webhookdb/sponsy"

module Webhookdb::Replicator::SponsyV1Mixin
  include Webhookdb::DBAdapter::ColumnTypes

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:sponsy_id, TEXT, data_key: "id")
  end

  def _timestamp_column_name
    return :updated_at
  end

  def _ts_columns
    return [
      Webhookdb::Replicator::Column.new(:created_at, TIMESTAMP, data_key: "createdAt"),
      Webhookdb::Replicator::Column.new(
        :updated_at, TIMESTAMP,
        data_key: "updatedAt",
        defaulter: Webhookdb::Replicator::Column.defaulter_from_resource_field(:created_at),
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

  def root_integration
    return @root_integration ||= Webhookdb::Replicator.find_at_root!(self.service_integration,
                                                                     service_name: "sponsy_publication_v1",)
  end

  def find_api_key
    return self.root_integration.backfill_secret
  end

  def _resource_and_event(request)
    return request.body, nil
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:updated_at] < Sequel[:excluded][:updated_at]
  end

  def _webhook_response(_request)
    # There are no webhooks to respond to, these are backfill-only integrations
    return Webhookdb::WebhookResponse.ok
  end

  # @return [Webhookdb::Replicator::StateMachineStep]
  def calculate_backfill_state_machine
    check_dep = self.class.descriptor.dependency_descriptor
    if check_dep && (step = self.calculate_dependency_state_machine_step(dependency_help: ""))
      return step
    end
    step = Webhookdb::Replicator::StateMachineStep.new
    step.output = %(We will start replicating #{self.resource_name_plural} into your WebhookDB database.

#{self._query_help_output(prefix: "Once data is available, you can query #{self.resource_name_plural}.")})
    return step.completed
  end

  def on_dependency_webhook_upsert(_replicator, _payload, *)
    return
  end

  def _parallel_backfill = Webhookdb::Sponsy.parallel_backfill

  # Paginate from most recently updated.
  # We paginate until either:
  # - There are no more pages (the 'after cursor' is nil), or
  # - the updated at timestamp predates the time we last backfilled,
  #   meaning we probably already saw this update.
  def fetch_sponsy_page(tail, pagination_token, last_backfilled)
    url = self.api_url + tail
    begin
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
        timeout: Webhookdb::Sponsy.http_timeout,
      )
    rescue Webhookdb::Http::Error => e
      raise e unless e.status == 404
      self.logger.warn("sponsy_404", error: e)
      return [], nil
    end

    data = response.parsed_response.fetch("data")
    after_cursor = response.parsed_response.fetch("cursor", {}).fetch("afterCursor", nil)
    return data, nil if after_cursor.nil?
    return [], nil if data.empty?
    last_updated = data.last.fetch("updatedAt")
    return data, nil if last_updated < (last_backfilled || Time.at(0))
    return data, after_cursor
  end

  def _publication_backfillers(tail, publication_ids: nil, publication_slugs: nil)
    raise Webhookdb::Replicator::CredentialsMissing, "This Sponsy integration is missing a dependency with auth" if
      self.find_api_key.blank?

    publications_svc = self.service_integration.depends_on.replicator
    backfillers = publications_svc.admin_dataset(timeout: :fast) do |pub_ds|
      pub_ds = Webhookdb::Dbutil.reduce_expr(
        pub_ds,
        :|,
        [publication_ids && Sequel[sponsy_id: publication_ids], publication_slugs && Sequel[slug: publication_slugs]],
      )
      pub_ds = pub_ds.where(deleted_at: nil)
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
    include Webhookdb::Backfiller::Bulk

    attr_reader :upserting_replicator

    def initialize(service:, publication_id:, tail:)
      @service = service
      @upserting_replicator = @service
      @publication_id = publication_id
      @tail = tail
      super()
    end

    def upsert_page_size = 500
    def conditional_upsert? = true

    def prepare_body(body)
      body["publication_id"] = @publication_id
      body
    end

    def fetch_backfill_page(pagination_token, last_backfilled:)
      return @service.fetch_sponsy_page(
        "/v1/publications/#{@publication_id}#{@tail}", pagination_token, last_backfilled,
      )
    end
  end
end
