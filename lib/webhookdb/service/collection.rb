# frozen_string_literal: true

require "appydays/loggable"
require "grape"

require "webhookdb/service" unless defined?(Webhookdb::Service)

class Webhookdb::Service::Collection
  extend Webhookdb::MethodUtilities

  singleton_attr_reader :collection_entity_cache
  @collection_entity_cache = {}

  attr_reader :current_page, :items, :page_count, :total_count, :last_page

  def self.from_dataset(ds)
    if ds.respond_to?(:current_page)
      return self.new(
        ds.all,
        current_page: ds.current_page,
        page_count: ds.page_count,
        total_count: ds.pagination_record_count,
        last_page: ds.last_page?,
      )
    end
    return self.from_array(ds.all)
  end

  def self.from_array(array)
    return self.new(array, current_page: 1, page_count: 1, total_count: array.size, last_page: true)
  end

  def initialize(items, current_page:, page_count:, total_count:, last_page:)
    @items = items
    @current_page = current_page
    @page_count = page_count
    @last_page = last_page
    @total_count = total_count
  end

  def last_page?
    return @last_page
  end

  def more?
    return !@last_page
  end

  module Helpers
    def present_collection(collection, opts={})
      item_entity = opts.delete(:with) || opts.delete(:using)
      unless (collection_entity = Webhookdb::Service::Collection.collection_entity_cache[item_entity])
        collection_entity = Class.new(Webhookdb::Service::Entities::Base) do
          define_method(:object_type) do
            "list"
          end
          expose :items, using: item_entity
          expose :current_page
          expose :page_count
          expose :total_count
          expose :more?, as: :has_more
          expose :message do |_instance, options|
            options[:message]
          end
        end
        Webhookdb::Service::Collection.collection_entity_cache[item_entity] = collection_entity
      end
      opts[:with] = collection_entity

      wrapped =
        if collection.respond_to?(:dataset) || collection.is_a?(Sequel::Dataset)
          Webhookdb::Service::Collection.from_dataset(collection)
        elsif collection.is_a?(Webhookdb::Service::Collection)
          collection
        else
          Webhookdb::Service::Collection.from_array(collection)
        end

      present wrapped, opts
    end
  end
end
