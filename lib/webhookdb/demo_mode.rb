# frozen_string_literal: true

module Webhookdb::DemoMode
  include Appydays::Configurable
  include Appydays::Loggable

  configurable(:demo_mode) do
    setting :client_enabled, false
    setting :customer_email, "demo@webhookdb.com"
    setting :customer_org_key, "demo_org"
    setting :demo_org_id, 0
    setting :demo_data_api_host, "https://api.webhookdb.com"
    setting :example_datasets_enabled, false
  end

  class << self
    # Should requests to this server allow demo mode? Usually this is true when running
    # in a demo context, like initial local development.
    def client_enabled? = self.client_enabled
    # Should requests to this server respond to API requests for demo data?
    def server_enabled? = self.demo_org_id.positive?

    # @return [Array<Webhookdb::OrganizationMembership, Webhookdb::Replicator::StateMachineStep, String>]
    def handle_auth
      raise Webhookdb::InvalidPrecondition unless self.client_enabled?
      _, customer = Webhookdb::Customer.find_or_create_for_email(self.customer_email)
      membership = self._ensure_membership(customer)
      membership.organization.publish_deferred("syncdemodata", membership.organization_id)
      step = Webhookdb::Replicator::StateMachineStep.new.completed
      message = %(Hi there! This is a demo version of WebhookDB.

You have been logged in automatically.

Your WebhookDB organization has also been set up with replicators for some APIs, like GitHub.

Run `webhookdb db connection` to get your database connection string,
and see what data is available.

To set up a new replicator, run `webhookdb services list` to see what is available.

You can also head to `webhookdb.com/deploy-builder` to prepare an environment for a deployment
into your own environment, like AWS or Heroku.

Or check out https://webhookdb.com to sign up for WebhookDB Cloud so this is all managed for you.)
      return membership, step, message
    end

    def _ensure_membership(customer)
      org = Webhookdb::Organization.find_or_create(key: self.customer_org_key) do |o|
        o.name = "Demo Org"
        o.billing_email = customer.email
      end
      mem = customer.all_memberships_dataset[organization: org] || customer.add_membership(
        organization: org, membership_role: Webhookdb::Role.admin_role, verified: true, is_default: true,
      )
      return mem
    end

    def build_demo_data
      evar = "DEMO_MODE_DEMO_ORG_ID"
      raise Webhookdb::InvalidPrecondition, "#{evar} not set" unless self.server_enabled?
      org = Webhookdb::Organization[self.demo_org_id] or
        raise Webhookdb::InvalidPrecondition, "#{evar} #{self.demo_org_id} does not exist"
      demo_sints = org.service_integrations.select { |sint| sint.service_name.start_with?("github_") }
      data = demo_sints.map do |sint|
        rows_data = sint.replicator.readonly_dataset { |ds| ds.select_map(:data) }
        {
          service_name: sint.service_name,
          rows_data:,
        }
      end
      return {data:}
    end

    def sync_demo_data(org)
      can_run = Webhookdb::DemoMode.client_enabled? ||
        Webhookdb::DemoMode.example_datasets_enabled
      return false unless can_run
      resp = Webhookdb::Http.post("#{self.demo_data_api_host}/v1/demo/data", timeout: nil, logger: self.logger)
      # First, create/migrate all service integrations from the demo server.
      sints_and_datas = []
      resp.parsed_response["data"].each do |h|
        service_name = h.fetch("service_name")
        table_name = "#{service_name}_demo"
        sint = org.service_integrations.find { |si| si.table_name == table_name } ||
          org.add_service_integration(service_name:, table_name:)
        sints_and_datas << [sint, h.fetch("rows_data")]
      end
      org.migrate_replication_tables
      # Now populate them with data.
      sints_and_datas.each do |(sint, rows)|
        repl = sint.replicator
        rows.each do |row|
          repl.upsert_webhook_body(row)
        end
      end
      return true
    end
  end
end
