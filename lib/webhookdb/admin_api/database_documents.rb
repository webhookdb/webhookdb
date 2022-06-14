# frozen_string_literal: true

require "grape"

require "webhookdb/admin_api"

class Webhookdb::AdminAPI::DatabaseDocuments < Webhookdb::AdminAPI::V1
  resource :database_documents do
    route_param :id, type: Integer do
      auth(:skip)
      get :view do
        (doc = Webhookdb::DatabaseDocument[params[:id]]) or forbidden!
        doc.check_url(request.url) or forbidden!
        content_type doc.content_type
        env["api.format"] = :binary
        body doc.content
      end
    end
  end
end
