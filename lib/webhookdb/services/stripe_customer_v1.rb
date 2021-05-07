# frozen_string_literal: true

require "httparty"
require "stripe"

class Webhookdb::Services::StripeCustomerV1 < Webhookdb::Services::Base
  include Appydays::Loggable

  def webhook_response(request)
    # info for debugging
    auth = request.env["HTTP_STRIPE_SIGNATURE"]
    log_params = {auth: auth, stripe_body: request.params}
    self.logger.debug "webhook hit stripe customer endpoint", log_params

    return [401, {"Content-Type" => "application/json"}, '{"message": "missing hmac"}'] if auth.nil?

    request.body.rewind
    request_data = request.body.read

    begin
      Stripe::Webhook.construct_event(
        request_data, auth, self.service_integration.webhook_secret,
      )
    rescue Stripe::SignatureVerificationError => e
      # Invalid signature
      self.logger.debug "stripe signature verification error: ", e
      return [401, {"Content-Type" => "application/json"}, '{"message": "invalid hmac"}']
    end

    return [200, {"Content-Type" => "application/json"}, '{"o":"k"}']
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:stripe_id, "text")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:balance, "real"),
      Webhookdb::Services::Column.new(:created, "integer"),
      Webhookdb::Services::Column.new(:email, "text"),
      Webhookdb::Services::Column.new(:name, "text"),
      Webhookdb::Services::Column.new(:phone, "text"),
      Webhookdb::Services::Column.new(:updated, "integer"),
    ]
  end

  def _update_where_expr
    return Sequel[self.table_sym][:updated] < Sequel[:excluded][:updated]
  end

  def _prepare_for_insert(body)
    # When we are backfilling, we recieve information from the charge api, but when
    # we recieve a webhook we are getting that information from the events api. Because
    # of this, the data we get in each case will have a different shape. This conditional
    # at the beginning of the function accomodates that difference in shape and ensures
    # that information from a webhook will always supercede information obtained through
    # backfilling.
    updated = 0
    obj_of_interest = body
    if body["object"] == "event"
      updated = body["created"]
      obj_of_interest = body["data"]["object"]
    end
    return {
      data: obj_of_interest.to_json,
      balance: obj_of_interest["balance"],
      created: obj_of_interest["created"],
      email: obj_of_interest["email"],
      name: obj_of_interest["name"],
      phone: obj_of_interest["phone"],
      stripe_id: obj_of_interest["id"],
      updated: updated,
    }
  end

  def _fetch_backfill_page(pagination_token)
    unless (url = pagination_token)
      url = ""
    end
    url = "https://api.stripe.com/v1/customers" + url
    response = HTTParty.get(
      url,
      basic_auth: {username: self.service_integration.backfill_key},
      logger: self.logger,
    )
    self.logger.error "stripe charge backfilling", response
    raise response if response.code >= 300
    data = response.parsed_response
    if data["has_more"]
      last_item_id = data["data"][-1]["id"]
      next_page_param = "?starting_after=" + last_item_id
    end
    return data["data"], next_page_param
  end
end
