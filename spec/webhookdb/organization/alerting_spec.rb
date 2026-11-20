# frozen_string_literal: true

require "webhookdb/messages/specs"

RSpec.describe Webhookdb::Organization::Alerting, :db do
  let(:org) { Webhookdb::Fixtures.organization.create }
  let(:sint) { Webhookdb::Fixtures.service_integration.create(organization: org) }
  let(:alerting) { org.alerting }
  let(:membership_fac) { Webhookdb::Fixtures.organization_membership.org(org) }

  let(:tmpl) do
    tmpl = Webhookdb::Messages::Testers::Basic.new
    tmpl.define_singleton_method(:signature) { "tester" }
    si = sint
    tmpl.define_singleton_method(:service_integration) { si }
    tmpl
  end

  describe "dispatch_alert" do
    it "requires #signature and #service_integration on the template" do
      t = Webhookdb::Messages::Testers::Basic.new
      expect do
        alerting.dispatch_alert(t)
      end.to raise_error(Webhookdb::InvalidPrecondition, /define a #signature/)

      t.define_singleton_method(:signature) { "x" }
      expect do
        alerting.dispatch_alert(t)
      end.to raise_error(Webhookdb::InvalidPrecondition, /basic must return its ServiceIntegration/)
    end

    describe "without any registered error handlers" do
      it "runs the default dispatch" do
        admin = membership_fac.verified.admin.create
        alerting.dispatch_alert(tmpl)
        expect(Webhookdb::Message::Delivery.all).to contain_exactly(
          have_attributes(template: "specs/basic", recipient: be === admin.customer),
        )
      end
    end

    describe "with registered error handlers" do
      it "performs an async job to alert about the error", sidekiq: :fake do
        eh1 = Webhookdb::Fixtures.organization_error_handler(organization: org).create
        eh2 = Webhookdb::Fixtures.organization_error_handler(organization: org).create
        Webhookdb::Fixtures.organization_error_handler.create
        alerting.dispatch_alert(tmpl)
        expect(Sidekiq).to have_queue("netout").consisting_of(
          job_hash(
            Webhookdb::Jobs::OrganizationErrorHandlerDispatch,
            args: contain_exactly(eh1.id, include("signature" => "tester", "service_integration_name" => "fake_v1")),
          ),
          job_hash(
            Webhookdb::Jobs::OrganizationErrorHandlerDispatch,
            args: contain_exactly(eh2.id, include("signature" => "tester", "service_integration_name" => "fake_v1")),
          ),
        )
      end

      it "serializes job args without bothering sidekiq" do
        eh1 = Webhookdb::Fixtures.organization_error_handler(organization: org).create
        req = stub_request(:post, eh1.url).and_return(status: 200)
        tmpl.define_singleton_method(:liquid_drops) do
          {msg: (+"not encoded \xC2\xA9 copyright").force_encoding("ASCII-8BIT")}
        end
        alerting.dispatch_alert(tmpl)
        expect(req).to have_been_made
      end
    end
  end

  describe "dispatch_alert_default", :no_transaction_check, reset_configuration: described_class do
    it "sends the message to all verified admins" do
      admin1 = membership_fac.verified.admin.create
      admin2 = membership_fac.verified.admin.create
      invited_admin = membership_fac.invite.admin.create
      member = membership_fac.verified.create

      alerting.dispatch_alert(tmpl)
      expect(Webhookdb::Message::Delivery.all).to contain_exactly(
        have_attributes(template: "specs/basic", recipient: be === admin1.customer),
        have_attributes(template: "specs/basic", recipient: be === admin2.customer),
      )
    end

    it "alerts only for the configured interval for a given signature" do
      admin1 = membership_fac.verified.admin.create
      admin2 = membership_fac.verified.admin.create

      # Messages initially sent
      described_class.interval = 60
      alerting.dispatch_alert(tmpl)
      expect(Webhookdb::Message::Delivery.all).to contain_exactly(
        have_attributes(template: "specs/basic", recipient: be === admin1.customer),
        have_attributes(template: "specs/basic", recipient: be === admin2.customer),
      )
      # No messages sent before interval
      Timecop.travel(30.seconds.from_now) { alerting.dispatch_alert(tmpl) }
      expect(Webhookdb::Message::Delivery.all).to have_length(2)
      # Shorten interval, messages should be sent
      described_class.interval = 20
      Timecop.travel(30.seconds.from_now) { alerting.dispatch_alert(tmpl) }
      expect(Webhookdb::Message::Delivery.all).to have_length(4)
      # Add an admin; only they should get the message
      membership_fac.verified.admin.create
      org.verified_memberships(reload: true)
      alerting.dispatch_alert(tmpl)
      expect(Webhookdb::Message::Delivery.all).to have_length(5)
    end

    it "does not send more than the configured emails to a given customer each day" do
      admin1 = membership_fac.verified.admin.create
      admin2 = membership_fac.verified.admin.create

      # Messages initially sent
      described_class.interval = 0
      described_class.max_alerts_per_customer_per_day = 20
      100.times do |i|
        Timecop.travel(i.seconds.from_now) do
          alerting.dispatch_alert(tmpl)
        end
      end
      # Sent 20 emails to each admin
      expect(Webhookdb::Message::Delivery.all).to have_length(40)
      # Move to tomorrow and assert we send emails
      Timecop.travel(25.hours.from_now) do
        alerting.dispatch_alert(tmpl)
      end
      expect(Webhookdb::Message::Delivery.all).to have_length(42)
    end

    it "can alert on a separate connection to get around idempotency", no_transaction_check: false do
      admin = membership_fac.verified.admin.create
      admin.db.transaction do
        alerting.dispatch_alert(tmpl, separate_connection: true)
      end
      expect(Webhookdb::Message::Delivery.all).to have_length(1)
    end
  end
end
