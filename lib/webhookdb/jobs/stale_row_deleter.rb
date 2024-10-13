# frozen_string_literal: true

require "webhookdb/async/job"

# Run the +stale_row_deleter+ for each service integration
# which match the given where/exclude clauses.
# This is generally used to delete old stale rows in the backend
# (by passing initial: true) when a new stale row deleter is deployed.
class Webhookdb::Jobs::StaleRowDeleter
  extend Webhookdb::Async::Job

  def perform(opts={})
    opts = opts.deep_symbolize_keys
    opts[:where] ||= {}
    opts[:exclude] ||= {}
    opts[:initial] ||= false
    ds = Webhookdb::ServiceIntegration.dataset
    ds = ds.where(opts[:where]) if opts[:where]
    ds = ds.exclude(opts[:exclude]) if opts[:exclude]
    ds.each do |sint|
      self.with_log_tags(sint.log_tags) do
        d = sint.replicator.stale_row_deleter
        opts[:initial] ? d.run_initial : d.run
      end
    end
  end
end
