# frozen_string_literal: true

RSpec.describe "Webhookdb::Message::Body", :db, :messaging do
  let(:described_class) { Webhookdb::Message::Body }

  it "can fixture and full text search" do
    expect { Webhookdb::Fixtures.message_body.html.create.text_search_reindex }.to_not raise_error
    expect { Webhookdb::Fixtures.message_body.text.create.text_search_reindex }.to_not raise_error
    expect { Webhookdb::Fixtures.message_body.subject.create.text_search_reindex }.to_not raise_error
  end
end
