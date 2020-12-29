# frozen_string_literal: true

require "webhookdb" unless defined?(Webhookdb)

module Webhookdb::Enumerable
  module_function def group_and_count_by(enumerable)
    result = Hash.new(0)
    enumerable.each do |item|
      key = yield(item)
      result[key] += 1
    end
    return result
  end

  module_function def group_and_count(enumerable)
    return group_and_count_by(enumerable) { |k| k }
  end
end
