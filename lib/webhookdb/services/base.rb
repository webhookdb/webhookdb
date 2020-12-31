# frozen_string_literal: true

class Webhookdb::Services::Base
  # @return [Webhookdb::ServiceIntegration]
  attr_reader :service_integration

  def initialize(service_integration)
    @service_integration = service_integration
  end

  def table_sym
    return self.service_integration.table_name.to_sym
  end

  # Check if the webhook is verified using the http request.
  # We must do this immediatley in the endpoint itself,
  # since verification may include info specific to the request content
  # (like, it can be whitespace sensitive).
  #
  # @return [Boolean] if the webhook is verified.
  def webhook_http_request_verified?(request)
    raise NotImplementedError
  end

  # The string body the webhook response with.
  # Some webhooks (twilio) require a meaningful response.
  #
  # @return [String]
  def webhook_response_body
    return "ok"
  end

  # Headers to respond with. Normally empty.
  #
  # @return [Hash]
  def webhook_response_headers
    return {}
  end

  # If using a custom response body,
  # you probably need to override the content type too.
  #
  # @return [String]
  def webhook_response_content_type
    return "text/plain"
  end

  def create_table
    cmd = self._create_table_sql
    self.service_integration.db << cmd
  end

  def _create_table_sql
    tbl = self.service_integration.table_name
    remote_key_col = self._remote_key_column
    denormalized_columns = self._denormalized_columns
    lines = [
      "CREATE TABLE #{tbl} (",
      "  pk bigserial PRIMARY KEY,",
      "  data jsonb NOT NULL,",
      "  #{remote_key_col.name} #{remote_key_col.type} UNIQUE NOT NULL",
    ]
    denormalized_columns.each do |col|
      lines << ",  #{col.name} #{col.type} #{col.modifiers}"
    end
    lines << ");"
    denormalized_columns.each do |col|
      lines << "CREATE INDEX IF NOT EXISTS #{col.name}_idx ON #{tbl} (#{col.name})"
    end
    return lines.join("\n")
  end

  # Each integration needs a single remote key, like the Shopify order id for shopify orders,
  # or sid for Twilio resources. This column must be unique for the table.
  #
  # @abstract
  # @return [Webhookdb::Services::Column]
  def _remote_key_column
    raise NotImplementedError
  end

  # When an integration needs denormalized columns, specify them here.
  # Indices are created for each column.
  # Modifiers can be used if columns should have a default or whatever.
  #
  # @return [Array<Webhookdb::Services::Column]
  def _denormalized_columns
    return []
  end

  def upsert_webhook(headers:, body:)
    remote_key_col = self._remote_key_column
    inserting = {data: body.to_json}
    inserting.merge!(self._prepare_for_insert(headers, body))
    self.dataset.insert_conflict(
      target: remote_key_col.name,
      update: inserting,
      update_where: self._update_where_expr,
    ).insert(inserting)
  end

  # The argument for insert_conflict update_where clause.
  # Used to conditionally update, like updating only if a row is newer than what's stored.
  def _update_where_expr
    return nil
  end

  # Given the webhook headers and body, return a hash of what will be inserted.
  # It must include the key column and all denormalized columns.
  # TODO: Verify this and error if it's not the case when upserting
  #
  # @abstract
  # @return [Hash]
  def _prepare_for_insert(headers, body)
    raise NotImplementedError
  end

  # @return [Sequel::Dataset]
  def dataset
    return self.service_integration.db[self.table_sym]
  end
end
