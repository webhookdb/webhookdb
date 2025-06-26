# frozen_string_literal: true

require "webhookdb/service"

# Mixin for Grape API endpoints that use HTML rendering.
# This isn't tested well enough.
module Webhookdb::Service::ViewApi
  class FormError < Webhookdb::WebhookdbError
    attr_reader :status

    def initialize(msg, status=400)
      @status = status
      super(msg)
    end
  end

  def self.included(mod)
    mod.helpers do
      define_method(:render_liquid) do |
        data_rel_path,
        vars: {},
        content_type: "text/html",
        # If true, store view params in a cookie so we can re-render this page easily, usually to show errors.
        serialize_view_params: false
      |
        tmpl_file = File.open(Webhookdb::DATA_DIR + data_rel_path)
        liquid_tmpl = Liquid::Template.parse(tmpl_file.read)
        rendered = liquid_tmpl.render!(vars.deep_stringify_keys, registers: {})
        # Setting the content type isn't working
        _endpoint.content_type content_type
        if serialize_view_params
          _endpoint.cookies[:whdbviewparams] = {path: data_rel_path, vars:, content_type:}.to_json
        end
        env["api.format"] = :binary
        rendered
      end

      define_method(:_endpoint) do
        env["api.endpoint"]
      end
    end

    mod.rescue_from FormError do |e|
      if (params = _endpoint.cookies[:whdbviewparams]).blank?
        merror!(e.status, e.message)
      else
        begin
          h = JSON.parse(params)
        rescue StandardError => parse_err
          self.logger.error("parsing_whdbviewparams", parse_err)
          # If there are any problems, use fallback error handling.
          merror!(e.status, e.message)
        else
          vars = h["vars"].symbolize_keys
          vars[:error_message] = e.message
          new_html = render_liquid(
            h.fetch("path"),
            vars:,
            content_type: h.fetch("content_type"),
            serialize_view_params: true,
          )
          Rack::Response.new(new_html, e.status, {Rack::CONTENT_TYPE => h.fetch("content_type")})
        end
      end
    end
  end
end
