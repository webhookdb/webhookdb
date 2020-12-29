# frozen_string_literal: true

require "dotenv"

require "appydays/version"

##
# Wrapper over dotenv that will load the standard .env files for an environment
# (by convention, .env.<env>.local, .env.<env>, and .env).
#
# It can be called multiple times for the same environment.
#
# NOTE: Foreman assigns the $PORT environment variable BEFORE we load config
# (get to what is defined in worker, like puma.rb), so even if we have it in the .env files,
# it won't get used, because .env files don't stomp what is already in the environment
# (we don't want to use `overload`).
# So we have some trickery to overwrite only PORT.
module Appydays::Dotenviable
  def self.load(rack_env: nil, default_rack_env: "development", env: ENV)
    original_port = env.delete("PORT")
    rack_env ||= env["RACK_ENV"] || default_rack_env
    paths = [
      ".env.#{rack_env}.local",
      ".env.#{rack_env}",
      ".env",
    ]
    Dotenv.load(*paths)
    env["PORT"] ||= original_port
  end
end
