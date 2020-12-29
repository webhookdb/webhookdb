# frozen_string_literal: true

RSpec.describe "Webhookdb::Customer", :db do
  let(:described_class) { Webhookdb::Customer }

  it "can be inspected" do
    expect { Webhookdb::Customer.new.inspect }.to_not raise_error
  end

  describe "greeting" do
    it "uses the name if present" do
      expect(described_class.new(first_name: "Huck", last_name: "Finn").greeting).to eq("Huck")
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

  describe "verification" do
    let(:c) { Webhookdb::Fixtures.customer.unverified.instance }
    after(:each) do
      described_class.reset_configuration
    end

    it "does not change timestamp if already set" do
      expect(c).to_not be_phone_verified
      expect(c).to_not be_email_verified

      c.verify_phone
      c.verify_email
      expect(c).to be_phone_verified
      expect(c).to be_email_verified

      expect { c.verify_phone }.to(not_change { c.phone_verified_at })
      expect { c.verify_email }.to(not_change { c.email_verified_at })
    end

    it "verifies email if configured to skip" do
      described_class.handle_verification_skipping(c)
      expect(c).to_not be_email_verified
      expect(c).to_not be_phone_verified

      described_class.skip_email_verification = true
      described_class.handle_verification_skipping(c)
      expect(c).to be_email_verified
      expect(c).to_not be_phone_verified
    end

    it "verifies phone if configured to skip" do
      described_class.handle_verification_skipping(c)
      expect(c).to_not be_phone_verified
      expect(c).to_not be_email_verified

      described_class.skip_phone_verification = true
      described_class.handle_verification_skipping(c)
      expect(c).to be_phone_verified
      expect(c).to_not be_email_verified
    end

    it "verifies email and phone if allowlisted" do
      described_class.skip_verification_allowlist = ["*autoverify@lithic.tech"]
      c.email = "rob@lithic.tech"
      described_class.handle_verification_skipping(c)
      expect(c).to_not be_email_verified
      expect(c).to_not be_phone_verified

      c.email = "rob+autoverify@lithic.tech"
      described_class.handle_verification_skipping(c)
      expect(c).to be_email_verified
      expect(c).to be_phone_verified
    end
  end

  describe "onboarded?" do
    let(:onboarded) do
      Webhookdb::Fixtures.customer.create(
        password: "password",
      )
    end
    it "is true if name, email, phone, and password are set" do
      c = onboarded

      expect(c.refresh).to be_onboarded
      expect(c.refresh.set(first_name: "")).to be_onboarded
      expect(c.refresh.set(last_name: "")).to be_onboarded
      expect(c.refresh.set(first_name: "", last_name: "")).to_not be_onboarded
      expect(c.refresh.set(phone: "")).to_not be_onboarded
      expect(c.refresh.set(email: "")).to_not be_onboarded
      expect(c.refresh.set(password_digest: described_class::PLACEHOLDER_PASSWORD_DIGEST)).to_not be_onboarded
    end
  end
end
