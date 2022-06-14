# frozen_string_literal: true

require "webhookdb/admin_api/database_documents"
require "webhookdb/api/behaviors"

RSpec.describe Webhookdb::AdminAPI::DatabaseDocuments, :db do
  include Rack::Test::Methods

  let(:app) { described_class.build_app }
  let(:admin) { Webhookdb::Fixtures.customer.admin.create }

  describe "GET /admin/v1/database_documents/:id/view" do
    let(:doc) { Webhookdb::Fixtures.database_document.xml("<a><b>hi</b></a>").create }
    let(:url_path) { "/admin/v1/database_documents/#{doc.id}/view" }

    def sign_url(doc, **kw)
      u = "http://example.org#{url_path}"
      return doc.sign_url(u, **kw)
    end

    it "renders the document with the correct mediatype" do
      url = sign_url(doc, expire_at: 1.hour.from_now)

      get url

      expect(last_response).to have_status(200)
      expect(last_response.headers).to include("Content-Type" => "application/xml")
      expect(last_response.body).to eq("<a><b>hi</b></a>")
    end

    it "403s if the expiration is expired" do
      url = sign_url(doc, expire_at: 1.hour.ago)
      get url
      expect(last_response).to have_status(403)
    end

    it "403s if the signature is invalid" do
      url = sign_url(doc, expire_at: 1.hour.from_now)
      url += "x"
      get url
      expect(last_response).to have_status(403)
    end

    it "403s if the document does not exist" do
      url = sign_url(doc, expire_at: 1.hour.from_now)
      doc.destroy
      get url
      expect(last_response).to have_status(403)
    end
  end
end
