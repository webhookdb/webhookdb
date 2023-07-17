# frozen_string_literal: true

require "webhookdb/spec_helpers"

# Set :whdbisolation metadatabase. Use the isolation mode, or :reset to just reset config
# before and after the spec.
module Webhookdb::SpecHelpers::Whdb
  def self.included(context)
    context.before(:each) do |example|
      if (isomode = example.metadata[:whdbisolation])
        Webhookdb::Organization::DbBuilder.isolation_mode = isomode if isomode.is_a?(String)
        Webhookdb::Organization::DbBuilder.reset_configuration if isomode == :reset
      end
      if (regress = example.metadata[:regression_mode])
        Webhookdb.regression_mode = regress
      end
    end

    context.after(:each) do |example|
      if (mode = example.metadata[:whdbisolation])
        Webhookdb::Organization.dataset.each(&:remove_related_database) if mode != :reset
        Webhookdb::Organization::DbBuilder.reset_configuration
      end
      Webhookdb.regression_mode = false if example.metadata[:regression_mode]
    end

    context.around(:each) do |example|
      if example.metadata[:fake_replicator]
        Webhookdb::Replicator::Fake.reset
        begin
          example.run
        ensure
          Webhookdb::Replicator::Fake.reset
        end
      else
        example.run
      end
    end

    super
  end

  module_function def assign_connection_urls(o, **more)
    u = Webhookdb::Organization::DbBuilder.available_server_urls.sample
    raise "no server url?" if u.blank?
    o.update(
      readonly_connection_url_raw: u,
      admin_connection_url_raw: u,
      **more,
    )
  end

  module_function def create_dependency(service_integration)
    return service_integration.depends_on unless service_integration.depends_on.nil?
    dependency_descriptor = service_integration.replicator.descriptor.dependency_descriptor
    if dependency_descriptor.present?
      dependency = Webhookdb::Fixtures.service_integration.create(
        organization: service_integration.organization,
        service_name: dependency_descriptor.name,
      )
      service_integration.update(depends_on: dependency)
      return dependency
    end
    return nil
  end

  # If a service has dependencies, and those dependencies have dependencies, create
  # them recursively until all requirements are satisfied.
  module_function def create_all_dependencies(service_integration)
    sint = service_integration
    created = []
    loop do
      sint = create_dependency(sint)
      break if sint.nil?
      created << sint
    end
    return created
  end

  module_function def setup_dependencies(service_integration, insert_required_data_callback=nil)
    service_integration.replicator.create_table
    dep_sint = service_integration.depends_on
    return [] if dep_sint.nil?
    org = service_integration.organization
    dep_repls = []
    while dep_sint
      # Make sure all service integration orgs are the same instance, since it may be mutated
      # when we set up urls.
      raise Webhookdb::InvariantViolation, "service integration orgs must match" unless
        dep_sint.organization === org
      dep_sint.organization = org
      dep_repl = dep_sint.replicator
      dep_repl.create_table
      dep_repls << dep_repl
      dep_sint = dep_sint.depends_on
      break if dep_sint.nil?
    end
    insert_required_data_callback&.call(*dep_repls)
    return dep_repls
  end

  module_function def setup_upsert_webhook_example(this)
    this.let(:request_path) { nil }
    this.let(:request_method) { nil }
    this.let(:request_body) { nil }
    this.let(:request_headers) { nil }
    this.let(:webhook_request) do
      Webhookdb::Replicator::WebhookRequest.new(
        body: request_body, method: request_method, path: request_path, headers: request_headers,
      )
    end
    this.define_method(:upsert_webhook) do |svc, **kw|
      params = {body: request_body, headers: request_headers, method: request_method, path: request_path}
      params.merge!(**kw)
      svc.upsert_webhook(Webhookdb::Replicator::WebhookRequest.new(**params))
    end
  end

  # Creates and returns a new backfill job for the given integration or replicator,
  # and also runs the backfill.
  module_function def backfill(sint, **kw)
    sint = sint.service_integration if sint.respond_to?(:service_integration)
    bfjob = Webhookdb::Fixtures.backfill_job.for(sint).create(**kw)
    sint.replicator.backfill(bfjob)
    return bfjob
  end

  def refresh_row(row, replicator: nil)
    replicator ||= svc
    raise "Must provide :replicator or have :svc available" if replicator.nil?
    return replicator.readonly_dataset { |ds| ds[pk: row.fetch(:pk)] }
  end

  def update_row(row, replicator: nil, **fields)
    replicator ||= svc
    raise "Must provide :replicator or have :svc available" if replicator.nil?
    return replicator.admin_dataset { |ds| ds.where(pk: row.fetch(:pk)).update(fields) }
  end
end
