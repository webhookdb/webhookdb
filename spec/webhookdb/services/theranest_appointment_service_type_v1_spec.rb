# frozen_string_literal: true

require "support/shared_examples_for_services"

RSpec.describe Webhookdb::Services::TheranestAppointmentServiceTypeV1, :db do
  let(:org) { Webhookdb::Fixtures.organization.create }
  let(:appointment_id_one) { SecureRandom.hex(5) }
  let(:appointment_id_two) { SecureRandom.hex(5) }
  let(:appointment_sint) { fac.create(service_name: "theranest_appointment_v1") }
  let(:appointment_svc) { appointment_sint.service_instance }
  let(:sint) do
    fac.depending_on(appointment_sint).create(service_name: "theranest_appointment_service_type_v1").refresh
  end
  let(:svc) { sint.service_instance }
  let(:fac) { Webhookdb::Fixtures.service_integration(organization: org) }

  def auth_stub_request
    return stub_request(:post, "https://fake-url.com/home/signin").to_return(
      status: 200,
      headers: {"Set-Cookie" => "new_cookie"},
    )
  end

  def insert_appointment_rows
    appointment_svc.admin_dataset do |ds|
      ds.multi_insert([
                        {
                          data: '{"serviceTypeIds": ["abc123", "def456"] }',
                          external_id: appointment_id_one,
                        },
                        {
                          data: '{"serviceTypeIds": ["abc123", "ghi789"] }',
                          external_id: appointment_id_two,
                        },
                      ])
      return ds.order(:pk).last
    end
  end

  before(:each) { auth_stub_request }

  describe "basic service integration functionality" do
    before(:each) do
      org.prepare_database_connections
    end

    after(:each) do
      org.remove_related_database
    end

    it "can create its table in its org db" do
      svc.create_table
      svc.readonly_dataset do |ds|
        expect(ds.db).to be_table_exists(svc.qualified_table_sequel_identifier)
      end
      expect(sint.db).to_not be_table_exists(svc.qualified_table_sequel_identifier)
    end

    it "clears setup information" do
      sint.update(webhook_secret: "wh_sek")
      svc.clear_create_information
      expect(sint).to have_attributes(webhook_secret: "")
    end

    it "clears backfill information" do
      sint.update(api_url: "example.api.com", backfill_key: "bf_key", backfill_secret: "bf_sek")
      svc.clear_backfill_information
      expect(sint).to have_attributes(api_url: "")
      expect(sint).to have_attributes(backfill_key: "")
      expect(sint).to have_attributes(backfill_secret: "")
    end
  end

  it_behaves_like "a service implementation dependent on another", "theranest_appointment_service_type_v1",
                  "theranest_appointment_v1" do
    let(:no_dependencies_message) { "This integration requires Theranest Appointments to sync" }
  end

  # because this backfill process doesn't actually hit the API, we test a subset of the behavior we'd
  # expect from a backfill process that actually makes requests
  describe "backfill process" do
    before(:each) do
      org.prepare_database_connections
      appointment_svc.create_table
      svc.create_table
      insert_appointment_rows
    end

    after(:each) do
      org.remove_related_database
    end

    it "inserts records for pages of results" do
      # this implicitly tests that the service integration can insert into its table
      svc.backfill
      rows = svc.readonly_dataset(&:all)
      expect(rows).to have_length(4)
      expect(rows).to contain_exactly(
        include(
          appointment_id: appointment_id_one,
          service_type_id: "abc123",
          row_updated_at: be_within(10.seconds).of(DateTime.now),
        ),
        include(
          appointment_id: appointment_id_one,
          service_type_id: "def456",
          row_updated_at: be_within(10.seconds).of(DateTime.now),
        ),
        include(
          appointment_id: appointment_id_two,
          service_type_id: "abc123",
          row_updated_at: be_within(10.seconds).of(DateTime.now),
        ),
        include(
          appointment_id: appointment_id_two,
          service_type_id: "ghi789",
          row_updated_at: be_within(10.seconds).of(DateTime.now),
        ),
      )
    end

    it "emits the rowupsert event", :async, :do_not_defer_events do
      body = JSON.parse(<<~J)
        {
           "appointment_id":"#{appointment_id_one}",
           "service_type_id": "abc123"
        }
      J
      Webhookdb::Fixtures.webhook_subscription(service_integration: sint).create
      expect(Webhookdb::Jobs::SendWebhook).to receive(:perform_async).
        with(include(
               "payload" => match_array([sint.id, hash_including("row", "external_id", "external_id_column")]),
             ))
      appointment = appointment_svc.readonly_dataset(&:first)
      # this integration has no exact equivalent for `upsert_webhook`. `handle_item` mimics its functionality.
      backfiller = Webhookdb::Services::TheranestAppointmentServiceTypeV1::AppointmentServiceTypeBackfiller.new(
        appointment_service_type_svc: svc,
        appointment_id: appointment[:external_id],
        appointment_data: appointment[:data],
      )
      backfiller.handle_item(body)
    end
  end

  describe "state machine calculation" do
    describe "calculate_create_state_machine" do
      it "prompts for dependencies" do
        sint.update(depends_on: nil)
        appointment_sint.destroy
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          output: match("This integration requires Theranest Appointments to sync"),
        )
      end

      it "succeeds and prints a success response if the dependency is set" do
        sint.webhook_secret = "whsec_abcasdf"
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          complete: true,
          output: /You are all set/,
        )
      end
    end

    describe "calculate_backfill_state_machine" do
      it "returns org database info" do
        sm = sint.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          complete: true,
          output: match("We will start backfilling Theranest Appointment Service Types").and(
            match("you can query Theranest Appointment Service Types"),
          ),
        )
      end
    end
  end

  describe "specialized table behavior" do
    before(:each) do
      org.prepare_database_connections
    end

    after(:each) do
      org.remove_related_database
    end

    let(:old_item) do
      JSON.parse(<<~J)
        {
           "appointment_id":"#{appointment_id_one}",
           "service_type_id": "abc123"
        }
      J
    end
    let(:new_item) do
      JSON.parse(<<~J)
        {
           "appointment_id":"#{appointment_id_one}",
           "service_type_id": "abc123"
        }
      J
    end

    it "will upsert based on appointment and service_type ids" do
      appointment_svc.create_table
      insert_appointment_rows
      svc.create_table

      appointment = appointment_svc.readonly_dataset(&:first)
      backfiller = Webhookdb::Services::TheranestAppointmentServiceTypeV1::AppointmentServiceTypeBackfiller.new(
        appointment_service_type_svc: svc,
        appointment_id: appointment[:external_id],
        appointment_data: appointment[:data],
      )

      backfiller.handle_item(old_item)
      expect(svc.readonly_dataset(&:all)).to contain_exactly(
        include(
          appointment_id: appointment_id_one,
          service_type_id: "abc123",
          row_updated_at: be_within(1.seconds).of(DateTime.now),
        ),
      )

      backfiller.handle_item(new_item)
      expect(svc.readonly_dataset(&:all)).to contain_exactly(
        include(
          appointment_id: appointment_id_one,
          service_type_id: "abc123",
          row_updated_at: be_within(1.seconds).of(DateTime.now),
        ),
      )
    end
  end
end
