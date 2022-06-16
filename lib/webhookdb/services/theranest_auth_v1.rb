# frozen_string_literal: true

require "webhookdb/services/theranest_v1_mixin"

class Webhookdb::Services::TheranestAuthV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::TheranestV1Mixin

  # @return [Webhookdb::Services::Descriptor]
  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "theranest_auth_v1",
      ctor: self,
      feature_roles: ["theranest"],
      resource_name_singular: "Theranest Auth",
      resource_name_plural: "Theranest Auth",
    )
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:ignore_id, INTEGER)
  end

  def _denormalized_columns
    return []
  end

  def upsert_webhook(**_kwargs)
    raise NotImplementedError("This is a stub integration only for auth purposes.")
  end

  def webhook_response(_request)
    raise NotImplementedError("This is a stub integration only for auth purposes.")
  end

  def calculate_create_state_machine
    step = Webhookdb::Services::StateMachineStep.new
    unless self.service_integration.backfill_key.present?
      step.output = %(In order to create and maintain auth credentials for Theranest,
we will need a username and password. Enter those here:
      )
      return step.prompting("username").backfill_key(self.service_integration)
    end
    unless self.service_integration.backfill_secret.present?
      return step.secret_prompt("password").backfill_secret(self.service_integration)
    end

    step.output = %(WebhookDB will create a new auth cookie whenever one of this integration's
dependents requires access to the API.
    )
    return step.completed
  end

  def clear_create_information
    self.service_integration.update(webhook_secret: "")
  end

  def calculate_backfill_state_machine
    return self.calculate_create_state_machine
  end

  def clear_backfill_information
    self.clear_create_information
  end

  def get_auth_cookie
    sint = self.service_integration
    unless sint.backfill_key.present? && sint.backfill_secret.present?
      raise Webhookdb::Services::CredentialsMissing,
            "This integration requires Theranest Username and Password"
    end
    # check whether we already have an unexpired cookie
    if sint.last_backfilled_at.present? && sint.last_backfilled_at > 15.minutes.ago && sint.webhook_secret.present?
      return sint.webhook_secret
    end
    response = Webhookdb::Http.post(
      "#{sint.api_url}/home/signin",
      URI.encode_www_form({"Email" => sint.backfill_key, "Password" => sint.backfill_secret}),
      headers: {"Content-Type" => "application/x-www-form-urlencoded"},
      follow_redirects: false,
      logger: self.logger,
    )
    sint.update(webhook_secret: response.headers["set-cookie"], last_backfilled_at: DateTime.now)
    return sint.webhook_secret
  end

  def get_auth_headers
    return {"cookie" => self.get_auth_cookie}
  end
end
