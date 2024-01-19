# frozen_string_literal: true

module Webhookdb
  module Envfixer
    # If DOCKER_DEV is set, replace 'localhost' urls with 'host.docker.internal'.
    def self.replace_localhost_for_docker(env)
      return unless env["DOCKER_DEV"]
      env.each do |k, v|
        begin
          localhost = URI(v).host == "localhost"
        rescue StandardError
          next
        end
        next unless localhost
        env[k] = v.gsub("localhost", "host.docker.internal")
      end
    end

    # If MERGE_HEROKU_ENV, merge all of its environment vars into the current env
    def self.merge_heroku_env(env)
      return unless (heroku_app = env.fetch("MERGE_HEROKU_ENV", nil))
      text = `heroku config -j --app=#{heroku_app}`
      json = Oj.load(text)
      json.each do |k, v|
        env[k] = v
      end
    end
  end
end
