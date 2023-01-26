# frozen_string_literal: true

require "webhookdb/redis"

module Webhookdb::Replicator::GoogleAuthMixin
  EXPIRATION_BUFFER = 60

  def auth_cache_key_namespace = raise NotImplementedError("return something like 'gcalv1'")

  def access_token_cache_key(external_owner_id)
    parts = [self.auth_cache_key_namespace, "atok", self.service_integration.id.to_s, external_owner_id]
    return Webhookdb::Redis.cache_key(parts)
  end

  def delete_access_token(external_owner_id)
    key = self.access_token_cache_key(external_owner_id)
    Webhookdb::Redis.cache.with do |r|
      r.del(key)
    end
  end

  def _with_access_token(external_owner_id, get_refresh_token)
    key = self.access_token_cache_key(external_owner_id)
    Webhookdb::Redis.cache.with do |r|
      got = r.get(key)
      if got
        yield got
      else
        self.logger.info "creating_google_access_token", external_owner_id:
        refresh_token = get_refresh_token.call
        resp = Webhookdb::Http.post(
          "https://www.googleapis.com/oauth2/v4/token",
          {
            client_id: self.service_integration.backfill_key,
            client_secret: self.service_integration.backfill_secret,
            refresh_token:,
            grant_type: "refresh_token",
          },
          logger: self.logger,
        )
        access_token = resp.parsed_response.fetch("access_token")
        r.setex(key, resp.parsed_response["expires_in"] - EXPIRATION_BUFFER, access_token)
        yield access_token
      end
    end
  end

  def force_set_access_token(external_owner_id, access_token, expires_in: 60.minutes.to_i)
    key = self.access_token_cache_key(external_owner_id)
    Webhookdb::Redis.cache.with do |r|
      r.setex(key, expires_in, access_token)
      return access_token
    end
  end
end
