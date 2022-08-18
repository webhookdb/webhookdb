# frozen_string_literal: true

RSpec.shared_examples "a service column converter" do |isomorphic_proc|
  let(:initial_value) { super() }
  let(:resource) { nil }
  let(:expected_value) { super() }
  let(:db) { Webhookdb::Postgres::Model.db }

  it "returns expected value using ruby proc" do
    v = isomorphic_proc.ruby.call(initial_value, resource)
    expect(v).to eq(expected_value)
  end

  it "returns expected value using sql proc" do
    e = isomorphic_proc.sql.call(initial_value)
    v = db.select(e).first.to_a[0][1]
    expect(v).to eq(expected_value)
  end
end

RSpec.shared_examples "a service column defaulter" do |isomorphic_proc|
  let(:resource) { nil }
  let(:expected_value) { super() }
  let(:expected) { eq(expected_value) }
  let(:expected_query) { nil }
  let(:db) { Webhookdb::Postgres::Model.db }

  it "returns expected value using ruby proc" do
    v = isomorphic_proc.ruby.call(resource)
    expect(v).to expected
  end

  it "returns expected value using sql proc" do
    e = isomorphic_proc.sql.call
    if expected_query
      expect(db.select(e).sql).to eq(expected_query)
    else
      v = db.select(e).first.to_a[0][1]
      expect(v).to expected
    end
  end
end
