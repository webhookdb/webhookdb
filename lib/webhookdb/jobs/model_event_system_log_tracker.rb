# frozen_string_literal: true

require "webhookdb/async/job"
require "webhookdb/messages/invite"

class Webhookdb::Jobs::ModelEventSystemLogTracker
  extend Webhookdb::Async::Job

  on "webhookdb.*"

  def _perform(event)
    self.set_job_tags(event_name: event.name)
    case event.name
        when "webhookdb.customer.created"
          self.alert_customer_created(event)
        when "webhookdb.organization.created"
          self.alert_org_created(event)
        when "webhookdb.serviceintegration.created"
          self.alert_sint_created(event)
        when "webhookdb.serviceintegration.destroyed"
          self.alert_sint_destroyed(event)
      else
          self.set_job_tags(result: "noop")
      end
  end

  def create_event(title, body, link)
    Webhookdb::SystemLogEvent.create(
      at: Time.now,
      title:,
      body:,
      link:,
    )
  end

  def alert_customer_created(event)
    customer = self.lookup_model(Webhookdb::Customer, event)
    Webhookdb::DeveloperAlert.new(
      subsystem: "Customer Created",
      emoji: ":hook:",
      fallback: "New customer created: #{customer.inspect}",
      fields: [
        {title: "Id", value: customer.id, short: true},
        {title: "Email", value: customer.email, short: true},
        {title: "Link", value: customer.admin_link},
      ],
    ).emit
    create_event("Customer Created", customer.email, customer.admin_link)
    self.set_job_tags(result: "created_customer", email: customer.email)
  end

  def alert_org_created(event)
    org = self.lookup_model(Webhookdb::Organization, event)
    Webhookdb::DeveloperAlert.new(
      subsystem: "Organization Created",
      emoji: ":office:",
      fallback: "Organization created: #{org.inspect}",
      fields: [
        {title: "Id", value: org.id, short: true},
        {title: "Email", value: org.name, short: true},
        {title: "Link", value: org.admin_link},
      ],
    ).emit
    create_event("Organization Created", "#{org.name} (#{org.key})", org.admin_link)
    self.set_job_tags(result: "created_organization", key: org.key)
  end

  def alert_sint_created(event)
    sint = self.lookup_model(Webhookdb::ServiceIntegration, event)
    Webhookdb::DeveloperAlert.new(
      subsystem: "Integration Created",
      emoji: ":fax:",
      fallback: "Service Integration #{sint.service_name} (#{sint.opaque_id}) created",
      fields: [
        {title: "Id", value: sint.opaque_id, short: true},
        {title: "Service", value: sint.service_name, short: true},
        {title: "Table", value: sint.table_name, short: true},
        {title: "Org Name", value: sint.organization.name, short: true},
        {title: "Link", value: sint.admin_link},
      ],
    ).emit
    create_event(
      "Integration Created",
      "#{sint.service_name} (#{sint.opaque_id}) created in #{sint.organization.name}",
      sint.admin_link,
    )
    self.set_job_tags(result: "created_service_integration", opaque_id: sint.opaque_id, service: sint.service_name)
  end

  def alert_sint_destroyed(event)
    pl = event.payload[1].symbolize_keys
    org = Webhookdb::Organization[pl[:organization_id]]
    Webhookdb::DeveloperAlert.new(
      subsystem: "Integration Deleted",
      emoji: ":funeral_urn:",
      fallback: "Service Integration #{pl[:service_name]} (#{pl[:opaque_id]}) deleted",
      fields: [
        {title: "Id", value: pl[:opaque_id], short: true},
        {title: "Service", value: pl[:service_name], short: true},
        {title: "Table", value: pl[:table_name], short: true},
        {title: "Org Name", value: org.name, short: true},
        {title: "Link", value: org.admin_link},
      ],
    ).emit
    create_event(
      "Integration Deleted",
      "#{pl[:service_name]} (#{pl[:opaque_id]}) deleted from #{org.name}",
      org.admin_link,
    )
    self.set_job_tags(result: "destroyed_service_integration", opaque_id: pl[:oparque_id], service: pl[:service_name])
  end
end
