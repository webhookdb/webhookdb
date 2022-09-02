# frozen_string_literal: true

class Sidekiq::Worker::Setter
  class << self
    attr_accessor :override_item
  end
  def normalize_item(item)
    result = super
    result.merge!(self.class.override_item || {})
    return result
  end
end

module Amigo::SpecHelpers
  module_function def perform_inline(klass, args, item=nil)
    Sidekiq::Worker::Setter.override_item = item
    begin
      klass.perform_inline(*args)
    ensure
      Sidekiq::Worker::Setter.override_item = nil
    end
  end

  module_function def drain_jobs(q)
    all_jobs(q).each do |job|
      klass = job.item["class"].constantize
      perform_inline(klass, job.item["args"], job.item)
      job.delete
    end
  end

  module_function def all_jobs(q)
    arr = []
    q.each { |j| arr << j }
    return arr
  end

  class ServerCallbackMiddleware
    class << self
      attr_accessor :callback
    end

    def self.reset
      self.callback = nil
      return self
    end

    def self.new
      return self
    end

    def self.call(worker, job, queue)
      self.callback[worker, job, queue] if self.callback
      yield
    end
  end
end
