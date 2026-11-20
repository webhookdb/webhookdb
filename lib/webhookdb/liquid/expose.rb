# frozen_string_literal: true

require "liquid"

require "webhookdb"

# Allow customers to expose variables from a template
# using custom blocks and registers.
# See https://github.com/Shopify/liquid/wiki/Liquid-for-Programmers#create-your-own-tag-blocks
# for more info about blocks.
# See https://github.com/Shopify/liquid/wiki/Liquid-for-Programmers#difference-between-assigns-and-registers
# for info about "registers", which are used as template-render-specific mutable state
# (so we can mutate it in the tag/block, then inspect the mutated value after-the-fact).
class Webhookdb::Liquid::Expose < Liquid::Block
  def initialize(tag_name, var_name, options)
    super
    @var_name = var_name.strip.to_sym
  end

  def render(context)
    content = super
    context.registers[@var_name] = content
    ""
  end
end

Liquid::Environment.default.register_tag("expose", Webhookdb::Liquid::Expose)
