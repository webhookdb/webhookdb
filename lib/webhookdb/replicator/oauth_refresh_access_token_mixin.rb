# frozen_string_literal: true

require "webhookdb/redis"

module Webhookdb::Replicator::OAuthRefreshAccessTokenMixin
  EXPIRATION_BUFFER = 60

  def oauth_cache_key_namespace = raise NotImplementedError("return something like 'gcalv1'")
  def oauth_token_url = raise NotImplementedError("return something like https://someservice/oauth2/token")

  def oauth_http_timeout = raise NotImplementedError("return a timeout value for oauth http requests")

  def oauth_access_token_cache_key(oauth_user_id)
    parts = [self.oauth_cache_key_namespace, "atok", self.service_integration.id.to_s, oauth_user_id]
    return Webhookdb::Redis.cache_key(parts)
  end

  def delete_oauth_access_token(oauth_user_id)
    key = self.oauth_access_token_cache_key(oauth_user_id)
    Webhookdb::Redis.cache.with do |r|
      r.call("DEL", key)
    end
  end

  def _with_oauth_access_token(oauth_user_id, get_refresh_token)
    key = self.oauth_access_token_cache_key(oauth_user_id)
    Webhookdb::Redis.cache.with do |r|
      got = r.call("GET", key)
      if got
        yield got
      else
        self.logger.debug "creating_access_token", access_token_cache_key: key
        form_body = URI.encode_www_form(
          {
            client_id: self.service_integration.backfill_key,
            client_secret: self.service_integration.backfill_secret,
            refresh_token: get_refresh_token.call,
            grant_type: "refresh_token",
          },
        )
        resp = Webhookdb::Http.post(
          self.oauth_token_url,
          form_body,
          headers: {
            "Content-Type" => "application/x-www-form-urlencoded",
            "charset" => "utf-8",
          },
          logger: self.logger,
          timeout: self.oauth_http_timeout,
        )
        access_token = resp.parsed_response.fetch("access_token")
        r.call("SETEX", key, resp.parsed_response["expires_in"] - EXPIRATION_BUFFER, access_token)
        yield access_token
      end
    end
  end

  def force_set_oauth_access_token(oauth_user_id, access_token, expires_in: 60.minutes.to_i)
    key = self.oauth_access_token_cache_key(oauth_user_id)
    Webhookdb::Redis.cache.with do |r|
      r.call("SETEX", key, expires_in, access_token)
      return access_token
    end
  end
end
