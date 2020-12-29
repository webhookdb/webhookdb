# frozen_string_literal: true

RSpec.describe "system", :integration do
  it "responds to a health check" do
    response = HTTParty.get(url("/healthz"))
    expect(response).to party_status(200)
    expect(response).to party_response(eq(o: "k"))
  end

  it "responds to a status check" do
    response = HTTParty.get(url("/statusz"))
    expect(response).to party_status(200)
    expect(response).to party_response(include(:version))
  end
end
