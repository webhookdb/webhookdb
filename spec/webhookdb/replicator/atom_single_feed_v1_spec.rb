# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::AtomSingleFeedV1, :db do
  let(:org) { Webhookdb::Fixtures.organization.create }
  let(:fac) { Webhookdb::Fixtures.service_integration(organization: org) }
  let(:sint) { fac.create(service_name: "atom_single_feed_v1") }
  let(:svc) { sint.replicator }

  def entry_hash
    return Webhookdb::Xml::Atom.parse_entry(<<~J)
      <entry>
        <id>2602407</id>
        <title>Campsite Reporting at 1900-1999 NE OREGON ST</title>
        <updated>Fri, 9 Jun 2023 17:40:38 PST</updated>
        <summary>Campsite Reporting at 1900-1999 NE OREGON ST</summary>
        <category label="Campsite Reporting" term="Campsite Reporting"/>
        <published>2023-06-09T17:40:37.0-07:00</published>
        <georss:point>45.5285898898 -122.646064077</georss:point>
        <status>Open</status>
        <content type="html">&lt;img border=&qu</content>
      </entry>
    J
  end

  it_behaves_like "a replicator", "atom_single_feed_v1" do
    let(:sint) { super() }
    let(:body) { entry_hash }
    let(:expected_row) do
      include(
        :pk,
        data: hash_including("category" => {"label" => "Campsite Reporting", "term" => "Campsite Reporting"}),
        entry_id: "2602407",
        published: match_time("2023-06-10 00:40:37Z"),
        row_created_at: match_time(:now),
        title: "Campsite Reporting at 1900-1999 NE OREGON ST",
        updated: match_time("2023-06-10 01:40:38Z"),
        geo_lat: BigDecimal("45.5285898898"),
        geo_lng: BigDecimal("-122.646064077"),
      )
    end
    let(:supports_row_diff) { true }
  end

  it_behaves_like "a replicator that may have a minimal body", "theranest_appointment_v1" do
    let(:body) do
      Webhookdb::Xml::Atom.parse_entry(<<~J)
        <entry>
          <id>2602407</id>
          <title>Campsite Reporting at 1900-1999 NE OREGON ST</title>
          <updated>Fri, 9 Jun 2023 17:40:38 PST</updated>
        </entry>
      J
    end
  end

  it_behaves_like "a replicator that prevents overwriting new data with old", "atom_single_feed_v1" do
    let(:old_body) { entry_hash }
    let(:new_body) { entry_hash.merge("updated" => "Fri, 10 Jun 2023 17:40:38 PST", "title" => "new title") }
  end

  it_behaves_like "a replicator that verifies backfill secrets" do
    let(:correct_creds_sint) do
      Webhookdb::Fixtures.service_integration.create(
        service_name: "atom_single_feed_v1",
        api_url: "https://goodfeed",
      )
    end
    let(:incorrect_creds_sint) do
      Webhookdb::Fixtures.service_integration.create(
        service_name: "atom_single_feed_v1",
        api_url: "https://badfeed",
      )
    end

    def stub_service_request
      return stub_request(:get, "https://goodfeed").
          to_return(status: 200, body: "<feed />", headers: {"Content-Type" => "application/xml"})
    end

    def stub_service_request_error
      return stub_request(:get, "https://badfeed").
          to_return(status: 403, body: "", headers: {})
    end

    let(:failed_step_matchers) do
      {output: include("Sorry, we can't reach "), prompt_is_secret: false}
    end
  end

  it_behaves_like "a replicator that can backfill", "atom_single_feed_v1" do
    let(:page1_response) do
      <<~J
        <feed xmlns="http://www.w3.org/2005/Atom" xmlns:georss="http://www.georss.org/georss">
          <id>urn:uuid:2c8b4910-e5c4-11de-8a39-0800200c9a66</id>
          <title>City of Portland - iPhone Citizen Reports Submissions</title>
          <subtitle>Recent City of Portland iPhone application submissions</subtitle>
          <link rel="self" href="http://www.portlandoregon.gov/shared/cfm/trackit_devicerss.cfm"/>
          <updated>2023-06-09T17:46:27.411-07:00</updated>
          <category label="feedcategory" term="stuff"/>
          <author>
            <name>City of Portland</name>
            <email>cgis@portlandoregon.gov</email>
          </author>
          <icon>http://www.portlandonline.com/omf/index.cfm?c=39247&a=87997</icon>
          <entry>
            <id>2602407</id>
            <title>Campsite Reporting at 1900-1999 NE OREGON ST</title>
            <updated>Fri, 9 Jun 2023 17:40:38 PST</updated>
            <summary>Campsite Reporting at 1900-1999 NE OREGON ST</summary>
            <category label="Campsite Reporting" term="Campsite Reporting"/>
            <published>2023-06-09T17:40:37.0-07:00</published>
            <status>Open</status>
            <content type="html">
              &lt;img border=&quot;0&quot; src=&quot;http://www.portlandoregon.gov/trackit/deviceimage.cfm?&amp;input_value_id=1165110&amp;item_id=2602522&amp;thumb=yes&amp;width=200&amp;height=200&quot;&gt;&lt;dl&gt;&lt;dt&gt;Type&lt;/dt&gt;&lt;dd&gt;Campsite Reporting&lt;/dd&gt;&lt;dt&gt;Address&lt;/dt&gt;&lt;dd&gt;9700-9999 SE KNAPP ST&lt;/dd&gt;&lt;dt&gt;Comments&lt;/dt&gt;&lt;dd&gt;One of the newer.&lt;/dd&gt;&lt;dt&gt;Status&lt;/dt&gt;&lt;dd&gt;Open&lt;/dd&gt;&lt;/dl&gt;
            </content>
          </entry>
          <entry>
            <id>other-id</id>
            <title>More nonsense</title>
            <content type="text/csv" src="https://foo.csv"></content>
            <updated>Fri, 9 Jun 2023 17:40:38 PST</updated>
          </entry>
        </feed>
      J
    end
    let(:expected_items_count) { 2 }

    def stub_service_requests
      return [
        stub_request(:get, "https://fake-url.com").
            to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/xml"}),
      ]
    end

    def stub_empty_requests
      return [
        stub_request(:get, "https://fake-url.com").
            to_return(status: 200, body: "<feed />", headers: {"Content-Type" => "application/xml"}),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://fake-url.com").
          to_return(status: 500, body: "ahhh")
    end
  end

  describe "state machine calculation" do
    before(:each) do
      sint.update(api_url: "")
    end

    describe "calculate_backfill_state_machine" do
      it "prompts for the api url" do
        sm = sint.replicator.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          complete: false,
          output: include("entries from an Atom URL"),
          prompt: include("your URL here"),
        )
      end

      it "completes if api url is set" do
        req = stub_request(:get, "https://foo.bar").
          to_return(status: 200, body: "<feed />", headers: {"Content-Type" => "application/xml"})
        sint.api_url = "https://foo.bar"
        sm = sint.replicator.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          complete: true,
          output: include("Your feed will be synced momentarily"),
        )
        expect(req).to have_been_made
      end

      it "sets placeholder backfill key" do
        sm = sint.replicator.calculate_backfill_state_machine
        expect(sm).to have_attributes(needs_input: true)
        expect(sint.refresh).to have_attributes(backfill_key: be_present)
      end
    end
  end

  describe "webhook_response" do
    it "is ok" do
      expect(svc.webhook_response(fake_request)).to have_attributes(status: 202)
    end
  end
end
