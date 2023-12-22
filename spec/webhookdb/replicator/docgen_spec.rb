# frozen_string_literal: true

RSpec.describe Webhookdb::Replicator::Docgen, :db do
  it "builds markdown" do
    desc = Webhookdb::Replicator::AwsPricingV1.descriptor
    md = described_class.new(desc).markdown
    expect(md).to(include("title: AWS Price List"))
    expect(md).to(include("{% include prevnext.html"))
  end

  describe "documentable_descriptors" do
    it "skips webhookdb, fake, and other hidden descriptors" do
      names = described_class.documentable_descriptors.map(&:name)
      expect(names).to include("aws_pricing_v1")
      expect(names).to_not include(Webhookdb::Replicator::Fake.descriptor.name)
      expect(names).to_not include(Webhookdb::Replicator::WebhookdbCustomerV1.descriptor.name)
    end
  end
end
