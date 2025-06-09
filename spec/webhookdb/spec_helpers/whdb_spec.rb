# frozen_string_literal: true

require "webhookdb/spec_helpers/whdb"

RSpec.describe Webhookdb::SpecHelpers::Whdb, :db do
  describe "create_dependency" do
    let(:org) { Webhookdb::Fixtures.organization.create }
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "fake_dependent_v1", organization: org) }
    let(:fake_sint) { Webhookdb::Fixtures.service_integration.create(service_name: "fake_v1", organization: org) }

    it "returns nil if the integration has no dependency" do
      # fake_v1 does not have and dependencies
      dependency = create_dependency(fake_sint)
      expect(dependency).to be_nil
    end

    it "returns dependency if it already exists" do
      sint.depends_on = fake_sint
      dependency = create_dependency(sint)
      expect(dependency).to be === fake_sint
    end

    it "creates dependency and returns it if it doesn't exist" do
      fake_sint.destroy
      dependency = create_dependency(sint)

      # grab updated version of sint
      updated_sint = Webhookdb::ServiceIntegration[id: sint.id]
      expect(dependency).to not_be_nil
      expect(dependency).to be === updated_sint.depends_on
      expect(dependency.organization).to be === updated_sint.organization
      expect(dependency.service_name).to eq("fake_v1")
    end
  end

  describe "create_all_dependencies" do
    it "no-ops when sint has no dependencies" do
      fake_sint = Webhookdb::Fixtures.service_integration.create
      create_all_dependencies(fake_sint)
      expect(fake_sint.depends_on).to be_nil
      expect(Webhookdb::ServiceIntegration.where(organization: fake_sint.organization).all).to have_length(1)
    end

    it "creates all dependencies when they don't exist" do
      fake_dependent_dependent_sint = Webhookdb::Fixtures.service_integration.create(
        service_name: "fake_dependent_dependent_v1",
      )
      org = fake_dependent_dependent_sint.organization

      create_all_dependencies(fake_dependent_dependent_sint)
      expect(Webhookdb::ServiceIntegration.where(organization: org).all).to have_length(3)

      fake_dependent_sint = Webhookdb::ServiceIntegration[service_name: "fake_dependent_v1", organization: org]
      expect(fake_dependent_sint).to not_be_nil
      expect(fake_dependent_dependent_sint.depends_on).to be === fake_dependent_sint
      expect(fake_dependent_sint.organization).to be === org

      fake_sint = Webhookdb::ServiceIntegration[service_name: "fake_v1", organization: org]
      expect(fake_sint).to not_be_nil
      expect(fake_dependent_sint.depends_on).to be === fake_sint
      expect(fake_sint.organization).to be === org
    end
  end

  describe "LoggingThread" do
    it "prints and logs if the block errors" do
      errors = []
      prints = []
      e = RuntimeError.new("from test")
      t = logging_thread(errors, pp: prints.method(:push)) do
        raise e
      end
      t.join
      expect(errors).to include(e)
      expect(prints).to include(/from test/)
    end
  end
end
