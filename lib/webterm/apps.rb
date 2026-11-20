# frozen_string_literal: true

require "appydays/configurable"

class Webhookdb::Webterm
  include Appydays::Configurable

  configurable(:webterm) do
    setting :enforce_ssl, true
  end

  STATIC = File.expand_path("#{File.dirname(__FILE__)}/static")

  Files = Rack::Files.new(STATIC)

  class RedirectIndexHtmlToRoot
    REDIRECTS = ["", "/index.html"].freeze

    def initialize(app)
      @app = app
    end

    def call(env)
      return [302, {"Location" => "/terminal/"}, []] if REDIRECTS.include?(env[Rack::PATH_INFO])
      return @app.call(env)
    end
  end

  class ServeIndexHtmlFromRoot
    def initialize(app)
      @app = app
      @cached_html = nil
    end

    def call(env)
      return @app.call(env) unless env[Rack::PATH_INFO] == "/"
      if @cached_html.nil?
        html = File.read(File.join(STATIC, "index.html"))
        html.sub!("/* REPLACE_WHDB_ENV */", "window.whdbEnv = [['WEBHOOKDB_API_HOST', '#{Webhookdb.api_url}']]")
        @cached_html = html.chars
      end
      return [200, {Rack::CONTENT_TYPE => "text/html"}, @cached_html]
    end
  end
end
