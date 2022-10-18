# frozen_string_literal: true

class Webhookdb::Replicator::WebhookdbCustomerV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "webhookdb_customer_v1",
      ctor: ->(sint) { Webhookdb::Replicator::WebhookdbCustomerV1.new(sint) },
      feature_roles: ["internal"],
      resource_name_singular: "WebookDB Customer",
    )
  end

  def _webhook_response(request)
    sek = request.env["HTTP_WHDB_SECRET"]
    return Webhookdb::WebhookResponse.ok if sek == self.service_integration.webhook_secret
    return Webhookdb::WebhookResponse.error("Whdb-Secret header is missing") if sek.nil?
    return Webhookdb::WebhookResponse.error("Whdb-Secret value does not match configured secret")
  end

  def _timestamp_column_name
    return :updated_at
  end

  def calculate_create_state_machine
    step = Webhookdb::Replicator::StateMachineStep.new
    self.service_integration.update(webhook_secret: Webhookdb::Id.rand_enc(16)) if
      self.service_integration.webhook_secret.blank?
    step.output = %(WebhookDB is now listening for changes to #{self.resource_name_plural}
and will reflect them into the table for this service integration.

Whenever a #{self.resource_name_singular} changes, a request will be sent to:

  #{self._webhook_endpoint}

With the header:

  Whdb-Secret: #{self.service_integration.webhook_secret}

Which will be received by this running instance, so there's nothing else you have to do.

#{self._query_help_output}
)
    return step.completed
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:webhookdb_id, TEXT, data_key: "id")
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:created_at, TIMESTAMP, index: true),
      Webhookdb::Replicator::Column.new(:email, TEXT, index: true),
      Webhookdb::Replicator::Column.new(
        :updated_at,
        TIMESTAMP,
        index: true,
        defaulter: Webhookdb::Replicator::Column.defaulter_from_resource_field(:created_at),
      ),
    ]
  end

  def _resource_and_event(request)
    return request.body, nil
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:updated_at] < Sequel[:excluded][:updated_at]
  end
end
