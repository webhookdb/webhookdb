# frozen_string_literal: true

RSpec.describe "Webhookdb::Customer::ResetCode", :db do
  let(:described_class) { Webhookdb::Customer::ResetCode }
  let(:customer) { Webhookdb::Fixtures.customer.create }
  let(:reset_code) { Webhookdb::Fixtures.reset_code(customer:).create }

  it "has a generated six-digit token" do
    expect(reset_code.token).to match(/^\d{6}$/)
  end

  it "expires after 15 minutes" do
    expect(reset_code.expire_at).to be_within(1.minute).of(15.minutes.from_now)
  end

  it "can be expired" do
    expect(reset_code).to be_usable
    expect(reset_code).to_not be_expired
    expect(reset_code).to_not be_used
    reset_code.expire!
    expect(reset_code.expire_at).to be_within(1.minute).of(Time.now)
    expect(reset_code).to_not be_usable
    expect(reset_code).to be_expired
    expect(reset_code).to_not be_used
  end

  describe "using" do
    it "sets expire_at to the time of use and marks the code as used" do
      expect(reset_code).to be_usable
      expect(reset_code).to_not be_expired
      expect(reset_code).to_not be_used
      reset_code.use!
      expect(reset_code.expire_at).to be_within(1.minute).of(Time.now)
      expect(reset_code).to_not be_usable
      expect(reset_code).to be_expired
      expect(reset_code).to be_used
    end

    it "marks any unused code on the customer as expired" do
      other_code = described_class.create(customer:, transport: "email")
      expect(other_code).to be_usable
      expect(other_code).to_not be_expired
      expect(other_code).to_not be_used

      reset_code.use!
      expect(other_code.refresh.expire_at).to be_within(1.minute).of(Time.now)
      expect(other_code).to_not be_usable
      expect(other_code).to be_expired
      expect(other_code).to_not be_used
    end
  end

  describe "datasets" do
    it "can select only usable codes" do
      used = Webhookdb::Fixtures.reset_code(customer:).create.use!
      expired = Webhookdb::Fixtures.reset_code(customer:).create(expire_at: 1.minute.ago)
      usable = Webhookdb::Fixtures.reset_code(customer:).create

      expect(described_class.usable).to contain_exactly(usable)
    end
  end
end
