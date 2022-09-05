# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require "webhookdb"
Webhookdb.load_app

require "webhookdb/apps"
Webhookdb::Async.setup_web

map "/admin" do
  run Webhookdb::Apps::AdminAPI.build_app
end
map "/sidekiq" do
  run Webhookdb::Apps::SidekiqWeb.to_app
end
run Webhookdb::Apps::API.build_app
