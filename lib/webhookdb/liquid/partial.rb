# frozen_string_literal: true

require "webhookdb"
require "liquid"

class Webhookdb::Liquid::Partial < Liquid::Include
  def initialize(tag_name, name, options)
    name = "'partials/#{Regexp.last_match(1)}'" if name =~ /['"]([a-z0-9_]+)['"]/
    super
  end
end
Liquid::Environment.default.register_tag("partial", Webhookdb::Liquid::Partial)
