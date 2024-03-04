# frozen_string_literal: true

require "concurrent"

module SequelTextSearchable
  VERSION = "0.0.1"

  INDEX_MODES = [:async, :sync, :off].freeze
  DEFAULT_MODE = :async

  class << self
    def index_mode = @index_mode || DEFAULT_MODE

    def index_mode=(v)
      raise ArgumentError, "mode #{v.inspect} must be one of: #{INDEX_MODES}" unless
        INDEX_MODES.include?(v)
      @index_mode = v
    end

    def searchable_models = @searchable_models ||= []

    # Return the global threadpool for :async indexing.
    # Use at most a couple threads; if the work gets backed up,
    # have the caller run it. If the threads die,
    # the text update is lost, so we don't want to let it queue up forever.
    def threadpool
      return @threadpool ||= Concurrent::ThreadPoolExecutor.new(
        min_threads: 1,
        max_threads: 2,
        max_queue: 10,
        fallback_policy: :caller_runs,
      )
    end

    # Set your own threadpool.
    attr_writer :threadpool

    def reindex_all
      return self.searchable_models.sum(&:text_search_reindex_all)
    end
  end
end
