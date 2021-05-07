# frozen_string_literal: true

require "httparty"
require "webhookdb/shopify"

class Webhookdb::Services::ShopifyOrderV1 < Webhookdb::Services::Base
  include Appydays::Loggable

  def webhook_response(request)
    # info for debugging
    shopify_auth = request.env["HTTP_X_SHOPIFY_HMAC_SHA256"]
    log_params = {shopify_auth: shopify_auth, shopify_body: request.params}
    self.logger.debug "webhook hit shopify order endpoint", log_params

    return [401, {"Content-Type" => "application/json"}, '{"message": "missing hmac"}'] if shopify_auth.nil?
    request.body.rewind
    request_data = request.body.read
    verified = Webhookdb::Shopify.verify_webhook(request_data, shopify_auth, self.service_integration.webhook_secret)
    return [200, {"Content-Type" => "application/json"}, '{"o":"k"}'] if verified
    return [401, {"Content-Type" => "application/json"}, '{"message": "invalid hmac"}']
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:shopify_id, "text")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:app_id, "text"),
      Webhookdb::Services::Column.new(:cancelled_at, "timestamptz"),
      Webhookdb::Services::Column.new(:cart_token, "text"),
      Webhookdb::Services::Column.new(:checkout_token, "text"),
      Webhookdb::Services::Column.new(:closed_at, "timestamptz"),
      Webhookdb::Services::Column.new(:created_at, "timestamptz"),
      Webhookdb::Services::Column.new(:customer_id, "text"),
      Webhookdb::Services::Column.new(:email, "text"),
      Webhookdb::Services::Column.new(:name, "text"),
      Webhookdb::Services::Column.new(:order_number, "integer"),
      Webhookdb::Services::Column.new(:phone, "text"),
      Webhookdb::Services::Column.new(:token, "text"),
      Webhookdb::Services::Column.new(:updated_at, "timestamptz"),
      Webhookdb::Services::Column.new(:user_id, "text"),
    ]
  end

  def _update_where_expr
    return Sequel[self.table_sym][:updated_at] < Sequel[:excluded][:updated_at]
  end

  def _prepare_for_insert(body)
    return {
      app_id: body["app_id"],
      cancelled_at: body["cancelled_at"],
      cart_token: body["cart_token"],
      checkout_token: body["checkout_token"],
      closed_at: body["closed_at"],
      created_at: body["created_at"],
      customer_id: body["customer"]["id"],
      email: body["email"],
      name: body["name"],
      order_number: body["order_number"],
      phone: body["phone"],
      shopify_id: body["id"],
      token: body["token"],
      updated_at: body["updated_at"],
      user_id: body["user_id"],
    }
  end

  def _fetch_backfill_page(pagination_token)
    url = if pagination_token.blank?
            self.service_integration.api_url + "/admin/api/2021-04/orders.json?status=any"
    else
      pagination_token
          end
    response = HTTParty.get(
      url,
      basic_auth: {username: self.service_integration.backfill_key,
                   password: self.service_integration.backfill_secret,},
      logger: self.logger,
    )
    raise response if response.code >= 300
    data = response.parsed_response
    next_link = nil
    if response.headers.key?("link")
      links = Webhookdb::Shopify.parse_link_header(response.headers["link"])
      next_link = links[:next] if links.key?(:next)
    end
    return data["orders"], next_link
  end
end
