# frozen_string_literal: true

require "webhookdb/xml"

# rubocop:disable Layout/LineLength
RSpec.describe Webhookdb::Xml do
  describe described_class::Atom do
    describe "parse" do
      it "can parse a feed" do
        str = <<~J
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
              <georss:point>45.5285898898 -122.646064077</georss:point>
              <content type="text/csv" src="https://foo.csv"></content>
            </entry>
          </feed>
        J
        o = described_class.parse(str)
        expect(o).to eq(
          {
            "entries" => [
              {
                "id" => "2602407",
                "title" => "Campsite Reporting at 1900-1999 NE OREGON ST",
                "updated" => "Fri, 9 Jun 2023 17:40:38 PST",
                "summary" => "Campsite Reporting at 1900-1999 NE OREGON ST",
                "category" => {"label" => "Campsite Reporting", "term" => "Campsite Reporting"},
                "published" => "2023-06-09T17:40:37.0-07:00",
                "status" => "Open",
                "content" =>
                  {
                    "value" => "\n      img border=0 src=http://www.portlandoregon.gov/trackit/deviceimage.cfm?input_value_id=1165110item_id=2602522thumb=yeswidth=200height=200dldtType/dtddCampsite Reporting/dddtAddress/dtdd9700-9999 SE KNAPP ST/dddtComments/dtddOne of the newer./dddtStatus/dtddOpen/dd/dl\n    ",
                    "type" => "html",
                  },
              },
              {"georss:point" => "45.5285898898 -122.646064077", "content" => {"type" => "text/csv", "src" => "https://foo.csv"}},
            ],
            "id" => "urn:uuid:2c8b4910-e5c4-11de-8a39-0800200c9a66",
            "title" => "City of Portland - iPhone Citizen Reports Submissions",
            "subtitle" => "Recent City of Portland iPhone application submissions",
            "link" => {"rel" => "self", "href" => "http://www.portlandoregon.gov/shared/cfm/trackit_devicerss.cfm"},
            "updated" => "2023-06-09T17:46:27.411-07:00",
            "category" => {"label" => "feedcategory", "term" => "stuff"},
            "author" => {"name" => "City of Portland", "email" => "cgis@portlandoregon.gov"},
            "icon" => "http://www.portlandonline.com/omf/index.cfm?c=39247=87997",
          },
        )
      end
    end
  end
end
# rubocop:enable Layout/LineLength
