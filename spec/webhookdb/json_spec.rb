# frozen_string_literal: true

require "webhookdb/json"

RSpec.describe Webhookdb::Json do
  obj = {
    t: Time.at(0.123456).in_time_zone("Europe/Helsinki"),
    r: Rational(1) / 3, i: 1,
    e: RuntimeError.new("ex"),
    h: "<a>hi</a>",
  }
  enc_json = '{"t":"1970-01-01T02:00:00.123+02:00","r":"1/3","i":1,"e":"ex","h":"<a>hi</a>"}'
  enc_obj = {"t" => "1970-01-01T02:00:00.123+02:00", "r" => "1/3", "i" => 1, "e" => "ex", "h" => "<a>hi</a>"}
  default_json = '{"t":"1970-01-01 02:00:00 +0200","r":"1/3","i":1,"e":"ex","h":"<a>hi</a>"}'
  default_obj = {"t" => "1970-01-01 02:00:00 +0200", "r" => "1/3", "i" => 1, "e" => "ex", "h" => "<a>hi</a>"}

  it "mimics default JSON" do
    expect(JSON.dump(obj)).to eq(default_json)
    expect(JSON.parse(default_json)).to eq(default_obj)
    expect(JSON.parse(enc_json)).to eq(enc_obj)
  end

  it "handles to_json" do
    expect(obj.to_json).to eq(enc_json)
  end

  it "can pretty generate" do
    # rubocop:disable Layout/LineLength
    expect(described_class.pretty_generate(obj)).to eq(
      "{\n  \"t\": \"1970-01-01T02:00:00.123+02:00\",\n  \"r\": \"1/3\",\n  \"i\": 1,\n  \"e\": \"ex\",\n  \"h\": \"<a>hi</a>\"\n}",
    )
    # rubocop:enable Layout/LineLength
  end

  it "handles html entities properly" do
    x = {html: "<div>hi</div>"}
    expect(JSON.dump(x)).to eq("{\"html\":\"<div>hi</div>\"}")
    expect(JSON.generate(x)).to eq("{\"html\":\"<div>hi</div>\"}")
    expect(x.as_json).to eq({"html" => "<div>hi</div>"})
    expect(x.to_json).to eq("{\"html\":\"<div>hi</div>\"}")
  end
end
