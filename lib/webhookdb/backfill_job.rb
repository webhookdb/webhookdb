# frozen_string_literal: true

# Represents the boundaries around a single execution of backfilling an integration.
# Each instance points to a single run of a single integration.
# There may be child jobs pointing to dependent integrations,
# or a parent job for a dependency backfill.
#
# When creating jobs, you can create a single job (a 'shallow' backfill)
# with +create+, or use +create_recursive+ to create jobs for all dependencies
# (a 'job group').
#
# Each job tracks when the backfill starts and ends.
# Iterating the full job graph can determine if a group is fully finished,
# or still in-progress.
#
class Webhookdb::BackfillJob < Webhookdb::Postgres::Model(:backfill_jobs)
  plugin :timestamps

  many_to_one :service_integration, class: "Webhookdb::ServiceIntegration"
  many_to_one :parent_job, class: "Webhookdb::BackfillJob"
  one_to_many :child_jobs, class: "Webhookdb::BackfillJob", key: :parent_job_id
  many_to_one :created_by, class: "Webhookdb::Customer"

  attr_accessor :_fixture_cascade

  # @return [Webhookdb::BackfillJob]
  def self.create_recursive(service_integration:, incremental:, created_by: nil, parent_job: nil)
    self.db.transaction do
      root = self.create(service_integration:, parent_job:, incremental:, created_by:)
      root.setup_recursive
      root
    end
  end

  # You should use ::create_recursive instead.
  # This is mostly here for use in tests/fixtures.
  def setup_recursive
    raise Webhookdb::InvalidPrecondition, "already has children" if self.child_jobs.present?
    self.service_integration.dependents.map do |dep|
      self.class.create_recursive(service_integration: dep, parent_job: self, incremental:)
    end
  end

  def incremental? = self.incremental

  def started? = !!self.started_at
  def finished? = !!self.finished_at

  def fully_finished_at
    parent_finished = self.finished_at
    return nil if parent_finished.nil?
    children_finished = self.child_jobs.map(&:fully_finished_at)
    return nil if children_finished.any?(&:nil?)
    children_finished << parent_finished
    return children_finished.max
  end

  def fully_finished? = !!self.fully_finished_at

  def status
    return "enqueued" unless self.started?
    return "finished" if self.fully_finished?
    return "inprogress"
  end

  def enqueue
    self.publish_deferred("run", self.id)
  end

  def enqueue_children
    self.child_jobs.each(&:enqueue)
  end

  #
  # :section: Sequel Hooks
  #

  def before_create
    self[:opaque_id] ||= Webhookdb::Id.new_opaque_id("bfj")
  end
end
