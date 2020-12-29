# frozen_string_literal: true

require "grape"

require "webhookdb/api"
require "webhookdb/aws"

class Webhookdb::API::Uploads < Webhookdb::API::V1
  resource :uploads do
    desc "Create a presigned URL that can be used to upload a file."
    params do
      requires :bucket, type: String, desc: "The bucket for which to generate a policy"
      optional :prefix, type: String, desc: "The desired prefix (folder) for the upload"
      requires :filename, type: String, desc: "The desired filename for the upload"
    end
    post :sign_url do
      current_customer
      url = Webhookdb::AWS.s3.presigned_put_url(params[:bucket], params[:filename], prefix: params[:prefix])
      status 200
      {url: url}
    end
  end
end
