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

Liquid::Template.register_filter(Webhookdb::Liquid::Filters)
