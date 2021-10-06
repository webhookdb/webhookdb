# frozen_string_literal: true

require "webhookdb/transistor"

class Webhookdb::Services::TransistorShowV1 < Webhookdb::Services::Base
  include Appydays::Loggable

  def _webhook_verified?(_request)
    # As of 9/15/21 there is no way to verify authenticity of these webhooks
    return true
  end

  def process_state_change(field, value)
    self.service_integration.db.transaction do
      self.service_integration.send("#{field}=", value)
      self.service_integration.save_changes
      case field
        when "backfill_key"
          return self.calculate_backfill_state_machine(self.service_integration.organization)
      else
          return
      end
    end
  end

  def analytics_table_name
    return "#{self.service_integration.table_name}_stats"
  end

  def calculate_create_state_machine(organization)
    step = Webhookdb::Services::StateMachineStep.new
    step.needs_input = false
    step.output = %(
Great! We've created your Transistor Shows Service Integration.
We will also include analytics data for each episode,
in the #{self.analytics_table_name} table.

You can query the database through your organization's Postgres connection string:

#{organization.readonly_connection_url}

You can also run a query through the CLI:

webhookdb db sql "SELECT * FROM #{self.service_integration.table_name}"
webhookdb db sql "SELECT * FROM #{self.analytics_table_name} WHERE date > '2021-01-15'"

Transistor's webhook support is spotty, so to fill your database,
we need to set up backfill functionality.

Run `webhookdb backfill #{self.service_integration.opaque_id}` to get started.
      )
    step.complete = true
    return step
  end

  def calculate_backfill_state_machine(_organization)
    step = Webhookdb::Services::StateMachineStep.new
    if self.service_integration.backfill_key.blank?
      step.needs_input = true
      step.output = %(
In order to backfill Transistor Shows, we need your API Key.

From your Transistor dashboard, go to the "Your Account" page,
at https://dashboard.transistor.fm/account
On the left side of the bottom of the page you should be able to see your API key.

Copy that API key.
      )
      step.prompt = "Paste or type your API key here:"
      step.prompt_is_secret = true
      step.post_to_url = "/v1/service_integrations/#{self.service_integration.opaque_id}/transition/backfill_key"
      step.complete = false
      return step
    end
    step.needs_input = false
    step.output = %(
Great! We are going to start backfilling your Transistor Show information.
      )
    step.complete = true
    return step
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:transistor_id, "text")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:author, "text"),
      Webhookdb::Services::Column.new(:created_at, "timestamptz"),
      Webhookdb::Services::Column.new(:description, "text"),
      Webhookdb::Services::Column.new(:title, "text"),
      Webhookdb::Services::Column.new(:website, "text"),
      Webhookdb::Services::Column.new(:updated_at, "timestamptz"),
    ]
  end

  def _update_where_expr
    return Sequel[self.table_sym][:updated_at] < Sequel[:excluded][:updated_at]
  end

  def _prepare_for_insert(body, **_kwargs)
    obj_of_interest = body.key?("data") ? body["data"] : body
    attributes = obj_of_interest.fetch("attributes")
    return {
      author: attributes.fetch("author"),
      created_at: attributes.fetch("created_at"),
      description: attributes.fetch("description"),
      title: attributes.fetch("title"),
      transistor_id: obj_of_interest.fetch("id"),
      updated_at: attributes.fetch("updated_at"),
      website: attributes.fetch("website"),
    }
  end

  def _fetch_backfill_page(pagination_token)
    pagination_token ||= [false, 1]
    iterating_over_private, page = pagination_token

    url = "https://api.transistor.fm/v1/shows"

    response = Webhookdb::Http.get(
      url,
      headers: {"x-api-key" => self.service_integration.backfill_key},
      body: {pagination: {page: page}, private: iterating_over_private},
      logger: self.logger,
    )
    data = response.parsed_response
    current_page = data["meta"]["currentPage"]
    total_pages = data["meta"]["totalPages"]
    shows = data["data"]

    if current_page < total_pages
      # If we still have pages on this list, go to the next one
      return shows, [iterating_over_private, current_page + 1]
    end
    # If we are done with the public list, we can now iterate over private shows
    return shows, [true, 1] unless iterating_over_private
    # Otherwise we are on the last page of our private list
    return shows, nil
  end
end
