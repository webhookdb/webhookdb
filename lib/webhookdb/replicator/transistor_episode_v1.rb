# frozen_string_literal: true

require "webhookdb/replicator/transistor_v1_mixin"
require "nokogiri"

class Webhookdb::Replicator::TransistorEpisodeV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::TransistorV1Mixin

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "transistor_episode_v1",
      ctor: ->(sint) { Webhookdb::Replicator::TransistorEpisodeV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "Transistor Episode",
    )
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:author, TEXT, data_key: ["attributes", "author"]),
      Webhookdb::Replicator::Column.new(
        :created_at,
        TIMESTAMP,
        index: true,
        data_key: ["attributes", "created_at"],
      ),
      Webhookdb::Replicator::Column.new(:duration, INTEGER, data_key: ["attributes", "duration"]),
      Webhookdb::Replicator::Column.new(:keywords, TEXT, data_key: ["attributes", "keywords"]),
      Webhookdb::Replicator::Column.new(:number, INTEGER, index: true, data_key: ["attributes", "number"]),
      Webhookdb::Replicator::Column.new(
        :published_at,
        TIMESTAMP,
        index: true,
        data_key: ["attributes", "published_at"],
      ),
      Webhookdb::Replicator::Column.new(:season, INTEGER, index: true, data_key: ["attributes", "season"]),
      Webhookdb::Replicator::Column.new(
        :show_id,
        TEXT,
        index: true,
        data_key: ["relationships", "show", "data", "id"],
      ),
      Webhookdb::Replicator::Column.new(:status, TEXT, data_key: ["attributes", "status"]),
      Webhookdb::Replicator::Column.new(:title, TEXT, data_key: ["attributes", "title"]),
      Webhookdb::Replicator::Column.new(:type, TEXT, data_key: ["attributes", "type"]),
      Webhookdb::Replicator::Column.new(
        :updated_at,
        TIMESTAMP,
        index: true,
        data_key: ["attributes", "updated_at"],
      ),
      # Ideally these would have converters, but they'd be very confusing, and when this was built
      # we only had one transistor user, so we truncated the table instead.
      Webhookdb::Replicator::Column.new(:api_format, INTEGER, optional: true),
      Webhookdb::Replicator::Column.new(:logical_summary, TEXT, optional: true),
      Webhookdb::Replicator::Column.new(:logical_description, TEXT, optional: true),
    ]
  end

  def _prepare_for_insert(resource, event, request, enrichment)
    h = super
    # Transistor merged their summary and description fields so they're authored
    # as one big 'description' HTML blob in February 2023. Previous to that,
    # there were separate summary and description fields
    # (we call this api_format 1).
    #
    # If we have a nil summary, we know this is a 'new' format (api_format 2).
    # In that case, look for the first line of the HTML,
    # and treat that as the summary. Anything else in the HTML is treated as
    # the remaining description. Some care is paid to whitespace, too,
    # since <br> tags can be used within an element.
    summary = resource.fetch("attributes").fetch("summary", nil)
    description = resource.fetch("attributes").fetch("description", nil)
    if summary.nil?
      h[:api_format] = 2
      parsed_desc = Nokogiri::HTML5.fragment(description)

      extracted_summary = self._extract_first_html_line_as_text(parsed_desc)
      h[:logical_description] = nil
      if extracted_summary
        h[:logical_summary] = extracted_summary
        h[:logical_description] = parsed_desc.to_s.strip if parsed_desc.inner_text.present?
      else
        h[:logical_summary] = parsed_desc.to_s.strip
      end
    else
      h[:logical_summary] = summary
      h[:logical_description] = description
      h[:api_format] = 1
    end
    return h
  end

  # Usually the Transistor HTML looks like <div>foo<br><br>hello</div>.
  # Extract 'foo' as text, remove leading <br>, and return <div>hello</div>.
  def _extract_first_html_line_as_text(element)
    # Assume the element starts with a div. It's possible this can be a 'p' tag in the future?
    first_div = element.css("div").first
    return nil unless first_div
    # Find the first text element. This is not the entire 'inner_text',
    # just the first piece of text ('foo' above, where inner_text would be 'foohello').
    leading_text = first_div.children.find { |n| n.is_a?(Nokogiri::XML::Text) }
    return nil unless leading_text
    # Remove all the <br> tags after the text.
    while (sibling = leading_text.next)
      break unless sibling.name == "br"
      sibling.remove
    end
    leading_text.remove # Remove the text element itself.
    return leading_text.inner_text.strip # It's easy for whitespace to show up, so get rid of it.
  end

  def upsert_has_deps?
    return true
  end

  def parse_date_from_api(date_string)
    return Time.strptime(date_string, "%d-%m-%Y")
  end

  def _fetch_backfill_page(pagination_token, last_backfilled:)
    url = "https://api.transistor.fm/v1/episodes"
    pagination_token = 1 if pagination_token.blank?
    response = Webhookdb::Http.get(
      url,
      headers: {"x-api-key" => self.service_integration.backfill_key},
      body: {pagination: {page: pagination_token, per: 500}},
      logger: self.logger,
    )
    data = response.parsed_response
    episodes = data["data"]
    current_page = data["meta"]["currentPage"]
    total_pages = data["meta"]["totalPages"]
    next_page = (current_page.to_i + 1 if current_page < total_pages)

    if last_backfilled.present?
      earliest_data_created = episodes.empty? ? Time.at(0) : episodes[-1].dig("attributes", "created_at")
      paged_to_already_seen_records = earliest_data_created < last_backfilled

      return episodes, nil if paged_to_already_seen_records
    end

    return episodes, next_page
  end
end
