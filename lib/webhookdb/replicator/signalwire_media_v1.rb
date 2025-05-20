# frozen_string_literal: true

require "webhookdb/errors"
require "webhookdb/signalwire"
require "webhookdb/messages/error_generic_backfill"

class Webhookdb::Replicator::SignalwireMediaV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  extend Webhookdb::MethodUtilities

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "signalwire_media_v1",
      ctor: ->(sint) { self.new(sint) },
      feature_roles: [],
      resource_name_singular: "SignalWire Media",
      dependency_descriptor: Webhookdb::Replicator::SignalwireMessageV1.descriptor,
      supports_backfill: true,
      api_docs_url: "https://developer.signalwire.com/compatibility-api/client-sdks/methods/media/list",
    )
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:signalwire_id, TEXT, data_key: "sid")
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(
        :date_created,
        TIMESTAMP,
        index: true,
        converter: Webhookdb::Replicator::Column::CONV_PARSE_TIME,
      ),
      Webhookdb::Replicator::Column.new(
        :date_updated,
        TIMESTAMP,
        index: true,
        converter: Webhookdb::Replicator::Column::CONV_PARSE_TIME,
      ),
      Webhookdb::Replicator::Column.new(:account_sid, TEXT),
      Webhookdb::Replicator::Column.new(:parent_sid, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:content_type, TEXT),
      Webhookdb::Replicator::Column.new(:uri, TEXT),
    ]
  end

  def _timestamp_column_name
    return :date_updated
  end

  def _resource_and_event(request)
    return request.body, nil
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:date_updated] < Sequel[:excluded][:date_updated]
  end

  def _webhook_response(*) = Webhookdb::WebhookResponse.ok

  # @return [Webhookdb::Replicator::StateMachineStep]
  def calculate_backfill_state_machine
    if (step = self.calculate_dependency_state_machine_step(dependency_help: ""))
      return step
    end
    step = Webhookdb::Replicator::StateMachineStep.new
    step.output = %(We will start replicating #{self.resource_name_plural} into your WebhookDB database.

#{self._query_help_output(prefix: "Once data is available, you can query #{self.resource_name_plural}.")})
    return step.completed
  end

  singleton_attr_accessor :dependency_upsert_disabled

  def on_dependency_webhook_upsert(_replicator, payload, *)
    # Need a way to bypass this for tests.
    return if self.class.dependency_upsert_disabled
    # We need to synchronously upsert the media for this row to make sure it's there when the upsert returns,
    # like for dependencies.
    # If the upsert fails, that's ok, the signalwire message backfill is recursive, so will run the media backfill,
    # which will upsert the missing media.
    bf = Backfiller.new(service: self, message_sid: payload.fetch(:signalwire_id))
    bf.backfill(nil)
    return
  end

  def _backfillers
    latest_date_created = self.admin_dataset(timeout: :fast) do |media_ds|
      media_ds.max(:date_created) || Time.at(0)
    end
    backfillers = self.service_integration.depends_on.replicator.admin_dataset(timeout: :fast) do |msg_ds|
      ds = msg_ds.
        where(Sequel[:date_created] >= latest_date_created).
        where(Sequel.pg_jsonb(:data).get_text("num_media").cast(:integer) > 0)
      msg_sids = ds.select_map(:signalwire_id)
      msg_sids.map do |sid|
        Backfiller.new(service: self, message_sid: sid)
      end
    end
    return backfillers
  end

  class Backfiller < Webhookdb::Backfiller
    def initialize(service:, message_sid:)
      @service = service
      @sint = service.service_integration
      @message_sint = @sint.depends_on
      @message_sid = message_sid
      super()
    end

    def handle_item(item)
      return @service.upsert_webhook_body(item)
    end

    def fetch_backfill_page(pagination_token, **)
      urltail = pagination_token ||
        "/api/laml/2010-04-01/Accounts/#{@message_sint.backfill_key}/Messages/#{@message_sid}/Media"
      data = @message_sint.replicator.signalwire_http_request(:get, urltail)
      media = data["media_list"]
      return media, data["next_page_uri"]
    end
  end

  def on_backfill_error(be)
    e = Webhookdb::Errors.find_cause(be) do |ex|
      next true if ex.is_a?(Webhookdb::Http::Error) && ex.status == 401
      next true if ex.is_a?(::SocketError)
    end
    # Handle this at the parent level
    return true if e
    return false
  end
end
