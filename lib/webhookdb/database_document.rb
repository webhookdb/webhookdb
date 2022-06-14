# frozen_string_literal: true

require "webhookdb/postgres/model"

# Simple model for jamming stuff into the database.
# Since WebhookDB isn't a resource-heavy application,
# and it's meant to be self-hosted,
# we may as well do this over pulling in an S3 or GCS dependeency.
class Webhookdb::DatabaseDocument < Webhookdb::Postgres::Model(:database_documents)
  include Appydays::Configurable
  configurable(:database_document) do
    setting :skip_authentication, false
    setting :skip_authentication_allowlist, [], convert: ->(s) { s.split }
  end

  plugin :column_encryption do |enc|
    enc.column :encryption_secret
  end

  def initialize(*)
    super
    self.encryption_secret ||= SecureRandom.hex(32)
  end

  def sign_url(path, expire_at:, params: {})
    uri = URI(path)
    q = params.merge(expire_at: expire_at.to_i)
    uri.query = HTTParty::Request::NON_RAILS_QUERY_STRING_NORMALIZER.call(q)
    url = uri.to_s
    sig = self.digest_url(url)
    return url + "&sig=#{sig}"
  end

  def check_url(url, now: Time.now)
    sig_idx = url.rindex("&sig=")
    return false if sig_idx.nil?
    without_sig = url[...sig_idx]
    got_sig = url[(sig_idx + 5)..]
    real_sig = self.digest_url(without_sig)
    return false unless ActiveSupport::SecurityUtils.secure_compare(got_sig, real_sig)
    expires = CGI.parse(URI(url).query || "?")["expire_at"]
    return false unless expires
    t = Time.at(expires.first.to_i)
    return false if t <= now
    return true
  end

  protected def digest_url(url)
    hmac = OpenSSL::HMAC.digest("sha256", self.encryption_secret, url)
    b = Base64.urlsafe_encode64(hmac, padding: false)
    return b
  end

  def presigned_view_url(expire_at:, **kw)
    url = "#{Webhookdb.api_url}/admin/v1/database_documents/#{self.id}/view"
    return self.sign_url(url, expire_at:, **kw)
  end
end
