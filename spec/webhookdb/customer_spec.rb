# frozen_string_literal: true

RSpec.describe "Webhookdb::Customer", :db do
  let(:described_class) { Webhookdb::Customer }

  it "can be inspected" do
    expect { Webhookdb::Customer.new.inspect }.to_not raise_error
  end

  describe "greeting" do
    it "uses the name if present" do
      expect(described_class.new(name: "Huck Finn").greeting).to eq("Huck Finn")
    end

    it "uses the default if none can be parsed" do
      expect(described_class.new.greeting).to eq("there")
    end
  end

  context "ensure_role" do
    let(:customer) { Webhookdb::Fixtures.customer.create }
    let(:role) { Webhookdb::Role.create(name: "customer-test") }
    it "can set a role by a role object" do
      customer.ensure_role(role)

      expect(customer.roles).to contain_exactly(role)
    end

    it "can set a role by the role name" do
      customer.ensure_role(role.name)
      expect(customer.roles).to contain_exactly(role)
    end

    it "noops if the customer already has the role" do
      customer.ensure_role(role.name)
      customer.ensure_role(role.name)
      customer.ensure_role(role)
      customer.ensure_role(role)
      expect(customer.roles).to contain_exactly(role)
    end
  end

  describe "authenticate" do
    let(:password) { "testtest1" }

    it "returns true if the password matches" do
      u = Webhookdb::Customer.new
      u.password = password
      expect(u.authenticate(password)).to be_truthy
    end

    it "returns false if the password does not match" do
      u = Webhookdb::Customer.new
      u.password = "testtest1"
      expect(u.authenticate("testtest2")).to be_falsey
    end

    it "returns false if the new password is blank" do
      u = Webhookdb::Customer.new
      expect(u.authenticate(nil)).to be_falsey
      expect(u.authenticate("")).to be_falsey

      space = "          "
      u.password = space
      expect(u.authenticate(space)).to be_truthy
    end

    it "cannot auth after being removed" do
      u = Webhookdb::Fixtures.customer.create
      u.soft_delete
      u.password = password
      expect(u.authenticate(password)).to be_falsey
    end
  end

  describe "setting password" do
    let(:customer) { Webhookdb::Fixtures.customer.instance }

    it "sets the digest to a bcrypt hash" do
      customer.password = "abcdefg123"
      expect(customer.password_digest.to_s).to have_length(described_class::PLACEHOLDER_PASSWORD_DIGEST.to_s.length)
    end

    it "uses the placeholder for a nil password" do
      customer.password = nil
      expect(customer.password_digest).to be === described_class::PLACEHOLDER_PASSWORD_DIGEST
    end

    it "fails if the password is not complex enough" do
      expect { customer.password = "" }.to raise_error(described_class::InvalidPassword)
    end
  end
end
