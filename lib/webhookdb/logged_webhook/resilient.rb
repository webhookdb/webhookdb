# frozen_string_literal: true

require "webhookdb/resilient_action"

class Webhookdb::LoggedWebhook::Resilient < Webhookdb::ResilientAction
  def logger = Webhookdb::LoggedWebhook.logger
  def database_urls = Webhookdb::LoggedWebhook.available_resilient_database_urls
  def rescued_exception_types = [Sequel::DatabaseError]
  def do_insert(kwargs, meta) = Webhookdb::LoggedWebhook.dataset.insert(kwargs.merge(meta))
  def table_name = Webhookdb::LoggedWebhook.resilient_webhooks_table_name
  def ping = Webhookdb::LoggedWebhook.db.execute("SELECT 1=1")

  def do_replay(kwargs, meta)
    lwh = Webhookdb::LoggedWebhook.create(kwargs.merge(meta))
    lwh.replay_async
  end
end
