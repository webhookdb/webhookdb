# frozen_string_literal: true

require "rspec/eventually"

require "webhookdb/async"

RSpec.describe "async workers", :integration do
  it "emails the customer on reset code create" do
    cu = with_async_publisher do
      Webhookdb::Fixtures.reset_code.email.create
    end

    expect { cu.customer.refresh.message_deliveries }.to eventually(have_attributes(length: 1))
  end
end
