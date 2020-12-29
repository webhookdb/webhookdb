# frozen_string_literal: true

require "rake/tasklib"

require "webhookdb"

module Webhookdb::Tasks
  class Heroku < Rake::TaskLib
    def initialize
      super()
      namespace :heroku do
        desc "Post to Slack if the number of dynos is not what is expected"
        task :check_dynos do
          require "webhookdb/heroku"
          require "webhookdb/slack"
          heroku = Webhookdb::Heroku.client
          info = heroku.formation.info Webhookdb::Heroku.app_name, "web"
          if info["quantity"] != Webhookdb::Heroku.target_web_dynos
            notifier = Webhookdb::Slack.new_notifier(
              channel: "#techops",
              username: "Monitor Bot",
              icon_emoji: ":hourglass_flowing_sand:",
            )
            notifier.post(
              # rubocop:disable Layout/LineLength
              text: "Heroku web dynos are scaled to #{info['quantity']}, expected #{Webhookdb::Heroku.target_web_dynos}",
              # rubocop:enable Layout/LineLength
            )
          end
        end
      end
    end
  end
end
