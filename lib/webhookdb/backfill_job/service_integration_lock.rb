# frozen_string_literal: true

# Helper table so backfill jobs can take exclusive locks on a service integration.
# Otherwise we end up backfilling the same integration concurrently.
class Webhookdb::BackfillJob::ServiceIntegrationLock < Webhookdb::Postgres::Model(
  :backfill_job_service_integration_locks,
)

  many_to_one :service_integration, class: "Webhookdb::ServiceIntegration"
end
