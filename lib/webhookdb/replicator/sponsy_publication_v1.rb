# frozen_string_literal: true

require "webhookdb/replicator/sponsy_v1_mixin"

class Webhookdb::Replicator::SponsyPublicationV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::SponsyV1Mixin

  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "sponsy_publication_v1",
      ctor: self,
      feature_roles: ["beta"],
      resource_name_singular: "Sponsy Publication",
    )
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:name, TEXT),
      Webhookdb::Replicator::Column.new(:slug, TEXT),
      Webhookdb::Replicator::Column.new(:type, TEXT),
      Webhookdb::Replicator::Column.new(:days, INTEGER_ARRAY),
    ].concat(self._ts_columns)
  end

  def _fetch_backfill_page(pagination_token, last_backfilled:)
    return self.fetch_sponsy_page("/v1/publications", pagination_token, last_backfilled)
  end

  def calculate_create_state_machine
    return self.calculate_backfill_state_machine
  end

  def calculate_backfill_state_machine
    step = Webhookdb::Replicator::StateMachineStep.new
    unless self.service_integration.backfill_secret.present?
      step.needs_input = true
      step.output = %(Great! Let's work on your Sponsy Publications integration.

Head over to your Sponsy dashboard and copy your API key:

https://getsponsy.com/settings/workspace
)
      return step.secret_prompt("API key").backfill_secret(self.service_integration)
    end

    unless (result = self.verify_backfill_credentials).verified
      self.service_integration.replicator.clear_backfill_information
      step.output = result.message
      return step.secret_prompt("API Key").backfill_secret(self.service_integration)
    end

    step.output = %(Great! We are going to start backfilling your Sponsy Publications,
and will keep them updated. You can can also add more Sponsy integrations.
Run `webhookdb services list` to see what's available.
#{self._query_help_output}
)
    return step.completed
  end

  def _verify_backfill_401_err_msg
    return "It looks like that API Key is invalid. Head back to https://getsponsy.com/settings/workspace, " \
           "copy the API key, and try again:"
  end
end
