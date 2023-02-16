# frozen_string_literal: true

require "webhookdb/redis"

module Webhookdb::Replicator::MicrosoftAuthMixin
  EXPIRATION_BUFFER = 60

  def auth_cache_key_namespace = raise NotImplementedError("return something like 'mscalv1'")

  def access_token_cache_key(microsoft_user_id)
    parts = [self.auth_cache_key_namespace, "atok", self.service_integration.id.to_s, microsoft_user_id]
    return Webhookdb::Redis.cache_key(parts)
  end

  def delete_access_token(microsoft_user_id)
    key = self.access_token_cache_key(microsoft_user_id)
    Webhookdb::Redis.cache.with do |r|
      r.del(key)
    end
  end

  def _with_access_token(microsoft_user_id, get_refresh_token)
    key = self.access_token_cache_key(microsoft_user_id)
    Webhookdb::Redis.cache.with do |r|
      got = r.get(key)
      if got
        yield got
      else
        self.logger.info "creating_outlook_access_token", microsoft_user_id:
        refresh_token = get_refresh_token.call
        client_id = self.service_integration.backfill_key
        client_secret = self.service_integration.backfill_secret
        form_body = URI.encode_www_form(
          {
            client_id:,
            client_secret:,
            refresh_token:,
            grant_type: "refresh_token",
          },
        )
        resp = Webhookdb::Http.post(
          "https://login.microsoftonline.com/organizations/oauth2/v2.0/token",
          form_body,
          headers: {
            "Content-Type" => "application/x-www-form-urlencoded",
            "charset" => "utf-8",
          },
          logger: self.logger,
        )
        access_token = resp.parsed_response.fetch("access_token")
        r.setex(key, resp.parsed_response["expires_in"] - EXPIRATION_BUFFER, access_token)
        yield access_token
      end
    end
  end

  def force_set_access_token(microsoft_user_id, access_token, expires_in: 60.minutes.to_i)
    key = self.access_token_cache_key(microsoft_user_id)
    Webhookdb::Redis.cache.with do |r|
      r.setex(key, expires_in, access_token)
      return access_token
    end
  end

  #  microsoft auth mixin
  # then outlook integration that stores encrypted refresh token
  # ms calendar user (handles auth, stores encrypted refresh token)
  # ms calendar (actual calendars, backfill on demand/scheduled)
  # ms calendar event (odata params to filter for what is changed since last backfill)
end
