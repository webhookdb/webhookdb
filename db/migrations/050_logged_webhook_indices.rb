# frozen_string_literal: true

Sequel.migration do
  no_transaction
  up do
    # These are optimized for Webhookdb::LoggedWebhook.trim. See code for details/coupling.
    run "CREATE INDEX CONCURRENTLY logged_webhooks_trim_unowned_idx ON logged_webhooks(inserted_at) " \
        "WHERE organization_id IS NULL"
    run "CREATE INDEX CONCURRENTLY logged_webhooks_trim_success_idx ON logged_webhooks(inserted_at) " \
        "WHERE organization_id IS NOT NULL AND response_status < 400 AND truncated_at IS NULL"
    run "CREATE INDEX CONCURRENTLY logged_webhooks_delete_success_idx ON logged_webhooks(inserted_at) " \
        "WHERE organization_id IS NOT NULL AND response_status < 400 AND truncated_at IS NOT NULL"
    run "CREATE INDEX CONCURRENTLY logged_webhooks_trim_failures_idx ON logged_webhooks(inserted_at) " \
        "WHERE organization_id IS NOT NULL AND response_status >= 400 AND truncated_at IS NULL"
    run "CREATE INDEX CONCURRENTLY logged_webhooks_delete_failures_idx ON logged_webhooks(inserted_at) " \
        "WHERE organization_id IS NOT NULL AND response_status >= 400 AND truncated_at IS NOT NULL"
  end
  down do
    run "DROP INDEX logged_webhooks_trim_unowned_idx"
    run "DROP INDEX logged_webhooks_trim_success_idx"
    run "DROP INDEX logged_webhooks_delete_success_idx"
    run "DROP INDEX logged_webhooks_trim_failures_idx"
    run "DROP INDEX logged_webhooks_delete_failures_idx"
  end
end
