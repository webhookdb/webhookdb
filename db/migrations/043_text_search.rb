# frozen_string_literal: true

Sequel.migration do
  change do
    searchable = [
      :backfill_jobs,
      :customers,
      :message_bodies,
      :message_deliveries,
      :organization_memberships,
      :organization_database_migrations,
      :organizations,
      :roles,
      :saved_queries,
      :saved_views,
      :service_integrations,
      :subscriptions,
      :sync_targets,
      :webhook_subscription_deliveries,
      :webhook_subscriptions,
    ]
    searchable.each do |tbl|
      alter_table(tbl) do
        add_column :text_search, :tsvector
      end
    end
  end
end
