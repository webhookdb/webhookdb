class Webhookdb::Replicator::LimeMaasV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "lime_maas_v1",
      ctor: ->(sint) { Webhookdb::Replicator::LimeMaasV1.new(sint) },
      feature_roles: ['lime'],
      resource_name_singular: "Lime MaaS",
      resource_name_plural: "Lime MaaS",
    )
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:ignore_id, INTEGER)
  end

  def _denormalized_columns
    return []
  end

  def _upsert_webhook(**_kwargs)
    raise NotImplementedError("This is a stub integration only for auth and url routing purposes.")
  end

  def _fetch_backfill_page(*)
    return [], nil
  end

  def _webhook_response(request)
    header = request.env["HTTP_AUTHORIZATION"]

    return Webhookdb::WebhookResponse.error("missing authorization header") if header.nil?
    return Webhookdb::WebhookResponse.error('malformed authorization header') unless header.start_with?('Bearer')
    token = header.split(' ').last
    return Webhookdb::WebhookResponse.error("invalid authorization token") unless
      ActiveSupport::SecurityUtils.secure_compare(token, self.service_integration.webhook_secret)
    return Webhookdb::WebhookResponse.ok
  end

  def calculate_create_state_machine
    step = Webhookdb::Replicator::StateMachineStep.new
    unless self.service_integration.webhook_secret.present?
      step.output = %(Let's go ahead and set up your Lime MaaS endpoints.
First, we need to use a secret value for the auth token that we'll use
to verify requests are actually from Lime.
You can generate a token yourself, or you can use '#{Webhookdb::Id.rand_enc(16)}'.
)
      return step.secret_prompt("auth token").webhook_secret(self.service_integration)
    end
    trips, orders = ['lime_trip_v1', 'lime_order_v1'].each do |svc|
      dep = self.find_dependent(svc)
      dep ||= Webhookdb::ServiceIntegration.create(
          organization: self.service_integration.organization,
          service_name: svc,
          table_name: Webhookdb::ServiceIntegration.new_table_name(self.service_integration.organization, svc),
      )
      dep
    end
    step.output = %(Great! We've made the MaaS Aggregator endpoints available.
Lime can call them, and we'll store the data.

#{trips.replicator.webhook_endpoint}
#{orders.replicator.webhook_endpoint}

You can see this information in your database tables:

  psql #{sint.organization.readonly_connection_url}
  > SELECT * FROM #{trips.table_name}
  > SELECT * FROM #{orders.table_name}

You can also run a query through the CLI:

  webhookdb db sql "SELECT * FROM #{trips.table_name}"
)
    return step.completed
  end

  def clear_create_information
    self.service_integration.update(webhook_secret: "")
  end

  def calculate_backfill_state_machine
    return self.calculate_create_state_machine
  end

  def clear_backfill_information
    self.clear_create_information
  end

  def dispatch_request_to(request)
    sint = case request.path
      when %r{/trips}
        self.find_dependent!("lime_trip_v1")
      when %r{/orders}
        self.find_dependent!("lime_order_v1")
      else
        raise "Request has invalid path: #{request.path}"
    end
    return sint.replicator
  end
end
