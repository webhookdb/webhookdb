# frozen_string_literal: true

require "webhookdb/microsoft_calendar"
require "webhookdb/replicator/microsoft_calendar_v1_mixin"

# Replicator for Microsoft Calendar rows.

class Webhookdb::Replicator::MicrosoftCalendarV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::MicrosoftCalendarV1Mixin

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "microsoft_calendar_v1",
      ctor: Webhookdb::Replicator::MicrosoftCalendarV1,
      feature_roles: ["microsoft", "beta"],
      resource_name_singular: "Outlook Calendar",
      dependency_descriptor: Webhookdb::Replicator::MicrosoftCalendarUserV1.descriptor,
    )
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:microsoft_calendar_id, TEXT, data_key: "id", index: true)
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:row_created_at, TIMESTAMP, index: true, optional: true, defaulter: :now),
      Webhookdb::Replicator::Column.new(:row_updated_at, TIMESTAMP, index: true, optional: true, defaulter: :now),
      Webhookdb::Replicator::Column.new(:microsoft_user_id, TEXT, data_key: "microsoft_user_id", index: true),
      Webhookdb::Replicator::Column.new(:is_default_calendar, BOOLEAN, data_key: "isDefaultCalendar"),
      # This is the value returned when we make a GET request to the event delta endpoint, which allows us to retrieve
      # information about changes to the calendar's events *incrementally*. This functions similarly to the Google
      # Calendar sync tokens, but they are just a URL. Note that we can only use the event delta functionality with a
      # user's "personal" calendar, i.e. the calendars for which `is_default_calendar` is true.
      Webhookdb::Replicator::Column.new(:delta_url, TEXT, skip_nil: true, optional: true),
    ]
  end

  def _timestamp_column_name
    return :row_updated_at
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:row_updated_at] < Sequel[:excluded][:row_updated_at]
  end

  def _upsert_update_expr(inserting, **_kwargs)
    update = super
    # Only set created_at if it's not set so the initial insert isn't modified.
    self._coalesce_excluded_on_update(update, [:row_created_at])
    return update
  end

  def _resource_to_data(resource, _event, _request)
    data = resource.dup
    data.delete("microsoft_user_id")
    return data
  end

  def calculate_create_state_machine
    return self._calculate_dependent_replicator_create_state_machine
  end

  # @param calendar_user_row [Hash<Symbol, Any>]
  # @param access_token [String]
  def sync_calendar_user_calendars(calendar_user_row, access_token)
    bf = CalendarBackfiller.new(
      calendar_svc: self,
      access_token:,
      user_row: calendar_user_row,
    )
    bf.backfill(nil)
  end

  class CalendarBackfiller < PaginatedBackfiller
    def initialize(access_token:, calendar_svc:, user_row:)
      @access_token = access_token
      @calendar_svc = calendar_svc
      @microsoft_user_id = user_row.fetch(:microsoft_user_id)
      super()
    end

    def handle_item(body)
      body["microsoft_user_id"] = @microsoft_user_id
      @calendar_svc.upsert_webhook_body(body)
    end

    def first_page_url_and_params
      return "https://graph.microsoft.com/v1.0/me/calendars", {"$top" => Webhookdb::MicrosoftCalendar.list_page_size}
    end

    def this_svc = @calendar_svc
  end
end
