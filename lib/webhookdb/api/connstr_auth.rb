# frozen_string_literal: true

require "grape"

# Some routes allow the SHA256 hash hexdigest connection string
# to be used in place of normal authentication (for example, queries to the database,
# which are not tied to a user). Do NOT extract this automatically (like org_identifier)
# since we want endpoints to specify that they use the param explicitly.
module Webhookdb::API::ConnstrAuth
  ALGOS = ["Sha256"].freeze

  def self.headers_desc
    return ALGOS.to_h do |algo|
      h = {
        required: false,
        algo:,
        description: "Hex digest of the #{algo} hash of the organization connection string, " \
                     "like Ruby's Digest::#{algo.upcase}.hexdigest(conn_str). " \
                     "Can be used in place of normal auth.",
      }
      ["Whdb-#{algo}-Conn", h]
    end
  end

  def self.find_authed(orgs, request)
    orgs.find do |o|
      self.headers_desc.each do |header_name, desc|
        header_value = request.headers[header_name]
        next if header_value.blank?
        org_value = Digest.const_get(desc.fetch(:algo).upcase.to_sym).send(:hexdigest, o.readonly_connection_url)
        return o if header_value == org_value
      end
    end
    return nil
  end
end
