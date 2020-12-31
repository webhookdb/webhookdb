# frozen_string_literal: true

class Webhookdb::Services::Fake < Webhookdb::Services::Base
  extend Webhookdb::MethodUtilities

  singleton_attr_accessor :webhook_verified
  singleton_attr_accessor :webhook_response_body
  singleton_attr_accessor :webhook_response_headers
  singleton_attr_accessor :webhook_response_content_type

  def self.reset
    self.webhook_verified = true
    self.webhook_response_body = nil
    self.webhook_response_headers = nil
    self.webhook_response_content_type = nil
  end

  def webhook_http_request_verified?(_request)
    return self.class.webhook_verified
  end

  def webhook_response_body
    return self.class.webhook_response_body || super
  end

  def webhook_response_headers
    return self.class.webhook_response_headers || super
  end

  def webhook_response_content_type
    return self.class.webhook_response_content_type || super
  end

  def _create_table_sql
    tbl = self.service_integration.table_name
    return <<~SQL
      CREATE TABLE #{tbl} (
        pk bigserial PRIMARY KEY,
        data jsonb NOT NULL,
        my_id text UNIQUE,
        other_field int
      );
      CREATE INDEX IF NOT EXISTS other_field_idx ON #{tbl} (other_field);
    SQL
  end
end
