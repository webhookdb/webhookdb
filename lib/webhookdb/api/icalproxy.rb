# frozen_string_literal: true

require "webhookdb/api"
require "webhookdb/jobs/icalendar_enqueue_syncs_for_urls"

class Webhookdb::API::Icalproxy < Webhookdb::API::V1
  resource :icalproxy do
    resource :webhook do
      post do
        merror!(402, "Api key not configured") unless Webhookdb::Icalendar.proxy_api_key.present?
        request_key = request.env["HTTP_AUTHORIZATION"] || ""
        configured_key = "Apikey #{Webhookdb::Icalendar.proxy_api_key}"
        verified = request_key && ActiveSupport::SecurityUtils.secure_compare(request_key, configured_key)
        merror!(401, "Invalid api key") unless verified
        urls = params.fetch(:urls)
        Webhookdb::Jobs::IcalendarEnqueueSyncsForUrls.perform_async(urls)
        status 202
        present({o: "k"})
      end
    end
  end
end
