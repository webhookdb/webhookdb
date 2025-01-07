# frozen_string_literal: true

require "liquid"
require "webhookdb"

module Webhookdb::Liquid::Filters
  def humanize(input)
    return input.humanize
  end

  def money(input)
    return input.format
  end
end

Liquid::Environment.default.register_filter(Webhookdb::Liquid::Filters)
