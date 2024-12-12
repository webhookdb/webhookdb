# frozen_string_literal: true

require "webhookdb/oye"

class Webhookdb::Replicator::OyeContactV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "oye_contact_v1",
      ctor: ->(sint) { self.new(sint) },
      feature_roles: [],
      resource_name_singular: "Oye Contact",
      supports_webhooks: false,
      supports_backfill: true,
    )
  end

  def _webhook_response(_request)
    return Webhookdb::WebhookResponse.new(
      status: 202,
      json: {o: "k"},
    )
  end

  def calculate_backfill_state_machine
    step = Webhookdb::Replicator::StateMachineStep.new
    unless self.service_integration.backfill_secret.present?
      step.needs_input = true
      step.output = %(Great! Let's set up your Oye contact replication.

To do this, we need your Oye API key. You will receive this from Oye when they allow you API access.)
      return step.secret_prompt("API Key").backfill_secret(self.service_integration)
    end

    unless (result = self.verify_backfill_credentials).verified
      self.service_integration.replicator.clear_backfill_information
      step.output = result.message
      return step.secret_prompt("API Key").backfill_secret(self.service_integration)
    end

    step.output = %(We are going to start replicating your Oye contacts, and will keep them updated.
#{self._query_help_output})
    return step.completed
  end

  def verify_backfill_credentials
    self._fetch_backfill_page(nil, last_backfilled: nil, is_verification: true)
    return CredentialVerificationResult.new(verified: true, message: "")
  rescue Webhookdb::Http::Error => e
    raise e unless e.status == 401
    return CredentialVerificationResult.new(
      verified: false,
      message: "It looks like that API Key is invalid. Please reenter your API key:",
    )
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:oye_id, TEXT, data_key: "id")
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:number, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:created_at, TIMESTAMP, index: true),
      Webhookdb::Replicator::Column.new(:updated_at, TIMESTAMP, index: true),
      Webhookdb::Replicator::Column.new(:status, TEXT),
    ]
  end

  def _timestamp_column_name
    return :updated_at
  end

  def _resource_and_event(request)
    return request.body, nil
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:updated_at] < Sequel[:excluded][:updated_at]
  end

  def _fetch_backfill_page(_, last_backfilled:, is_verification: false)
    url = "https://app.oyetext.org/api/v1/contacts"
    query = {}
    # There is no pagination from oye, so in order to test backfill credentials,
    # we add a search term that won't match anything, otherwise we'd potentially return
    # all results just to test key validation.
    query[:search] = "_do-not-match-anything_" if is_verification
    begin
      response = Webhookdb::Http.get(
        url,
        query,
        headers: {"Authorization" => "Bearer #{self.service_integration.backfill_secret}"},
        logger: self.logger,
        timeout: Webhookdb::Oye.http_timeout,
      )
    rescue Webhookdb::Http::Error => e
      return [], nil if e.status == 404 && e.to_s.include?("There are no contacts who match the search")
      raise e
    end
    data = response.parsed_response
    # Delete out these unmodified entries, no reason the DB needs to do it.
    data.delete_if { |c| c["updated_at"] < last_backfilled } if last_backfilled
    return data, nil
  end
end
