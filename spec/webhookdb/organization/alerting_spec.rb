# frozen_string_literal: true

require "webhookdb/messages/specs"

RSpec.describe Webhookdb::Organization::Alerting, :db do
  let(:org) { Webhookdb::Fixtures.organization.create }
  let(:alerting) { org.alerting }
  let(:membership_fac) { Webhookdb::Fixtures.organization_membership.org(org) }

  describe "dispatch_alert", :no_transaction_check, reset_configuration: described_class do
    it "sends the message to all verified admins" do
      admin1 = membership_fac.verified.admin.create
      admin2 = membership_fac.verified.admin.create
      invited_admin = membership_fac.invite.admin.create
      member = membership_fac.verified.create

      tmpl = Webhookdb::Messages::Testers::Basic.new
      tmpl.define_singleton_method(:signature) { "tester" }
      alerting.dispatch_alert(tmpl)
      expect(Webhookdb::Message::Delivery.all).to contain_exactly(
        have_attributes(template: "specs/basic", recipient: be === admin1.customer),
        have_attributes(template: "specs/basic", recipient: be === admin2.customer),
      )
    end

    it "requires a #signature field on the template" do
      expect do
        alerting.dispatch_alert(Webhookdb::Messages::Testers::Basic.new)
      end.to raise_error(Webhookdb::InvalidPrecondition, /define a #signature/)
    end

    it "alerts only for the configured interval for a given signature" do
      admin1 = membership_fac.verified.admin.create
      admin2 = membership_fac.verified.admin.create

      tmpl = Webhookdb::Messages::Testers::Basic.new
      tmpl.define_singleton_method(:signature) { "tester" }

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

      tmpl = Webhookdb::Messages::Testers::Basic.new
      tmpl.define_singleton_method(:signature) { "tester" }

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
      tmpl = Webhookdb::Messages::Testers::Basic.new
      tmpl.define_singleton_method(:signature) { "tester" }
      admin.db.transaction do
        alerting.dispatch_alert(tmpl, separate_connection: true)
      end
      expect(Webhookdb::Message::Delivery.all).to have_length(1)
    end
  end
end
