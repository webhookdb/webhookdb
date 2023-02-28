# frozen_string_literal: true

require "webhookdb/replicator/microsoft_calendar_v1_mixin"
require "webhookdb/microsoft_calendar"

class Webhookdb::Replicator::MicrosoftCalendarEventV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::MicrosoftCalendarV1Mixin

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "microsoft_calendar_event_v1",
      ctor: Webhookdb::Replicator::MicrosoftCalendarEventV1,
      feature_roles: ["microsoft", "beta"],
      resource_name_singular: "Outlook Calendar Event",
      dependency_descriptor: Webhookdb::Replicator::MicrosoftCalendarV1.descriptor,
    )
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:microsoft_event_id, TEXT, data_key: "id")
  end

  def _denormalized_columns
    ts_opts = {converter: Webhookdb::Replicator::Column::CONV_PARSE_TIME, optional: true}
    return [
      Webhookdb::Replicator::Column.new(:microsoft_calendar_id, TEXT),
      Webhookdb::Replicator::Column.new(:microsoft_user_id, TEXT),
      Webhookdb::Replicator::Column.new(:row_created_at, TIMESTAMP, defaulter: :now, optional: true),
      Webhookdb::Replicator::Column.new(:row_updated_at, TIMESTAMP, defaulter: :now, optional: true, index: true),
      # These are the values that Microsoft provides for when the event was created and updated, which are different
      # from the `row_created_at` value we use internally.
      Webhookdb::Replicator::Column.new(:created, TIMESTAMP, data_key: "createdDateTime", **ts_opts),
      Webhookdb::Replicator::Column.new(:updated, TIMESTAMP, data_key: "lastModifiedDateTime", **ts_opts),
      Webhookdb::Replicator::Column.new(:is_all_day, BOOLEAN, data_key: "isAllDay", optional: true),
      Webhookdb::Replicator::Column.new(:start_at, TIMESTAMP, data_key: ["start", "dateTime"], index: true, **ts_opts),
      Webhookdb::Replicator::Column.new(:start_timezone, TEXT, data_key: ["start", "timeZone"], optional: true),
      Webhookdb::Replicator::Column.new(:original_start_timezone, TEXT, data_key: "originalStartTimeZone",
                                                                        optional: true,),
      Webhookdb::Replicator::Column.new(:end_at, TIMESTAMP, data_key: ["end", "dateTime"], index: true, **ts_opts),
      Webhookdb::Replicator::Column.new(:end_timezone, TEXT, data_key: ["end", "timeZone"], optional: true),
      Webhookdb::Replicator::Column.new(:original_end_timezone, TEXT, data_key: "originalEndTimeZone", optional: true),
    ]
  end

  def _timestamp_column_name
    return :row_updated_at
  end

  def _update_where_expr
    # This isn't used normally due to bulk inserts
    return self.qualified_table_sequel_identifier[:row_updated_at] < Sequel[:excluded][:row_updated_at]
  end

  def _upsert_update_expr(inserting, **_kwargs)
    update = super
    # Only set the row created on insert. Note that the event timestamps :created and :updated
    # are stored verbatim, as explained above.
    self._coalesce_excluded_on_update(update, [:row_created_at])
    return update
  end

  def calculate_create_state_machine
    return self._calculate_dependent_replicator_create_state_machine
  end

  def _resource_to_data(resource, _event, _request)
    data = resource.dup
    data.delete("microsoft_user_id")
    data.delete("microsoft_calendar_id")
    return data
  end

  # @param calendar_row [Hash<Symbol, Any>]
  # @param access_token [String]
  def sync_calendar_events(calendar_svc, calendar_row, access_token)
    is_default_calendar =  calendar_row.fetch(:is_default_calendar)
    bf = if is_default_calendar
           EventDeltaBackfiller.new(
             event_svc: self,
             access_token:,
             calendar_row:,
             calendar_svc:,
           )
        else
          EventBackfiller.new(
            event_svc: self,
            access_token:,
            calendar_row:,
          )
         end

    bf.backfill(nil)
    bf.commit
  end

  module EventBackfillerMixin
    include Webhookdb::Backfiller::Bulk

    def upserting_replicator = @event_svc
    def upsert_page_size = Webhookdb::MicrosoftCalendar.upsert_page_size

    def prepare_body(body)
      body["microsoft_user_id"] = @microsoft_user_id
      body["microsoft_calendar_id"] = @microsoft_calendar_id
    end
  end

  class EventBackfiller < PaginatedBackfiller
    include EventBackfillerMixin

    def initialize(access_token:, event_svc:, calendar_row:)
      @access_token = access_token
      @event_svc = event_svc
      @microsoft_user_id = calendar_row.fetch(:microsoft_user_id)
      @microsoft_calendar_id = calendar_row.fetch(:microsoft_calendar_id)
      @pending_inserts = []
      super()
    end

    def this_svc = @event_svc

    def first_page_url_and_params
      params = {
        "$top" => Webhookdb::MicrosoftCalendar.list_page_size,
        "startDateTime" => Webhookdb::MicrosoftCalendar.calendar_view_start_time.iso8601,
        "endDateTime" => Webhookdb::MicrosoftCalendar.calendar_view_end_time.iso8601,
      }
      return "https://graph.microsoft.com/v1.0/me/calendars/#{@microsoft_calendar_id}/calendarView", params
    end

    def commit
      self.flush_pending_inserts
    end
  end

  # This backfiller is used for the "personal" calendar, which for whatever reason is the only calendar we can get
  # this kind of incremental change information for.
  class EventDeltaBackfiller < Webhookdb::Backfiller
    include EventBackfillerMixin

    def initialize(access_token:, event_svc:, calendar_svc:, calendar_row:)
      @access_token = access_token
      @calendar_svc = calendar_svc
      @event_svc = event_svc
      @delta_url = calendar_row.fetch(:delta_url)
      @microsoft_user_id = calendar_row.fetch(:microsoft_user_id)
      @microsoft_calendar_id = calendar_row.fetch(:microsoft_calendar_id)
      @pending_inserts = []
      super()
    end

    def fetch_backfill_page(pagination_token, **)
      headers = {"Authorization" => "Bearer #{@access_token}"}

      query = {}
      if pagination_token.present?
        url = pagination_token
      elsif @delta_url
        url = @delta_url
      else
        url = "https://graph.microsoft.com/v1.0/me/calendarView/delta"
        query["startDateTime"] = Webhookdb::MicrosoftCalendar.calendar_view_start_time.iso8601
        query["endDateTime"] = Webhookdb::MicrosoftCalendar.calendar_view_end_time.iso8601
      end

      response = Webhookdb::Http.get(
        url,
        query,
        headers:,
        logger: @event_svc.logger,
      )
      data = response.parsed_response.fetch("value")
      # the next page link is a full url that includes the page size param (`$top`) as well as the
      # pagination param (`$skip`)
      next_page_link = response.parsed_response.fetch("@odata.nextLink", nil)

      if next_page_link.nil?
        delta_url = response.parsed_response.fetch("@odata.deltaLink", nil)
        raise Webhookdb::InvalidPostcondition, "there should be a deltaLink value here" if delta_url.nil?
        @delta_url = delta_url
      end

      return data, next_page_link
    end

    def commit_next_delta_url(delta_url)
      @calendar_svc.admin_dataset do |calendar_ds|
        calendar_ds.where(microsoft_calendar_id: @microsoft_calendar_id).update(delta_url:)
      end
    end

    def commit
      self.commit_next_delta_url(@delta_url)
      self.flush_pending_inserts
    end
  end
end
