# frozen_string_literal: true

require "webhookdb/api"
require "webhookdb/oauth"
require "webhookdb/service/view_api"

class Webhookdb::API::Install < Webhookdb::API::V1
  include Webhookdb::Service::ViewApi

  namespace :install do
    helpers do
      def lookup_session!
        session = Webhookdb::OauthSession.where(
          Sequel[oauth_state: params[:state]] &
            Sequel.expr { created_at > 30.minutes.ago },
        ).first
        forbidden! unless session
        return session
      end

      def handle_login(email:, session:, action_url:)
        new_customer, me = Webhookdb::Customer.find_or_create_for_email(email)
        me.reset_codes_dataset.usable.each(&:expire!)
        me.add_reset_code(transport: "email")
        session.update(customer: me)
        rendered = render_liquid(
          "messages/web/install-customer-login.liquid",
          serialize_view_params: true,
          vars: {
            view: "otp",
            action_url:,
            oauth_state: session.oauth_state,
            new_customer:,
            email:,
          },
        )
        status 200
        body rendered
      end

      def find_and_verify_user(email:, otp_token:)
        (me = Webhookdb::Customer.with_email(email)) or forbidden!
        begin
          Webhookdb::Customer::ResetCode.use_code_with_token(otp_token) do |code|
            raise Webhookdb::Customer::ResetCode::Unusable unless code.customer === me
          end
        rescue Webhookdb::Customer::ResetCode::Unusable
          raise FormError.new("Sorry, that token is invalid. Please try again.", 403)
        end
        return me
      end

      def find_admin_membership(customer)
        _created, membership = Webhookdb::Customer.find_or_create_default_organization(customer)
        membership = customer.verified_memberships.find(&:admin?) unless membership.admin?
        return membership if membership
        raise FormError.new(
          "You must be an administrator of your WebhookDB organization to set up this app.",
          403,
        )
      end

      def exchange_authorization_code(provider:, session:)
        token = Webhookdb::Http.post(
          provider.exchange_url,
          {
            "code" => session.authorization_code,
            "redirect_uri" => provider.redirect_url,
            "grant_type" => provider.grant_type,
          },
          logger: self.logger,
          timeout: 10,
          basic_auth: provider.basic_auth,
        )
        return {
          refresh_token: token.parsed_response["refresh_token"],
          access_token: token.parsed_response["access_token"],
        }
      end
    end

    route_param :oauth_provider, type: String, values: Webhookdb::Oauth.registry.keys do
      helpers do
        def oauth_provider
          return @oauth_provider ||= Webhookdb::Oauth.provider(params[:oauth_provider])
        end
      end

      get do
        rendered = render_liquid(
          "messages/web/install.liquid",
          serialize_view_params: true,
          vars: {app_name: oauth_provider.app_name, action_url: "/v1/install/#{oauth_provider.key}"},
        )
        status 200
        body rendered
      end

      post do
        oauth_state = SecureRandom.hex(16)
        Webhookdb::OauthSession.create(
          oauth_state:,
          **Webhookdb::OauthSession.params_for_request(request),
        )
        auth_url = oauth_provider.authorization_url(state: oauth_state)
        redirect auth_url
      end

      params do
        requires :code, type: String, desc: "authorization code that we exchange for tokens"
        requires :state, type: String, desc: "the user session info string that we provided to the oauth flow"
      end
      get :callback do
        session = lookup_session!
        session.update(authorization_code: params[:code])
        redirect "/v1/install/#{oauth_provider.key}/login?state=#{session.oauth_state}"
      end

      params do
        requires :state, type: String
      end
      get :login do
        session = lookup_session!
        rendered = render_liquid(
          "messages/web/install-customer-login.liquid",
          serialize_view_params: true,
          vars: {
            view: "email",
            action_url: "/v1/install/#{oauth_provider.key}/login",
            oauth_state: session.oauth_state,
          },
        )
        status 200
        body rendered
      end

      params do
        requires :state, type: String, desc: "the user session info string that we provided to Front"
        optional :email, type: String
        optional :otp_token, type: String
      end
      post :login do
        session = lookup_session!
        email = params[:email]
        raise FormError.new("Email is required", 400) unless email.present?
        otp_token = params[:otp_token]
        if otp_token
          me = find_and_verify_user(email:, otp_token:)
          membership = find_admin_membership(me)
          begin
            token_resp = exchange_authorization_code(provider: oauth_provider, session:)
          rescue Webhookdb::Http::Error => e
            logger.warn "oauth_exchange_error", exception: e
            raise FormError.new(
              "Something went wrong getting your access token from #{oauth_provider.app_name}. Please start over",
              400,
            )
          end

          org = membership.organization
          org.db.transaction do
            org.prepare_database_connections?
            oauth_provider.build_marketplace_integrations(
              organization: org,
              access_token: token_resp[:access_token],
              refresh_token: token_resp[:refresh_token],
            )
          end
          rendered = render_liquid(
            "messages/web/install-success.liquid",
            serialize_view_params: true,
            vars: {
              app_name: oauth_provider.app_name,
              database_url: org.readonly_connection_url,
            },
          )
          status 200
          body rendered
        else
          handle_login(email:, session:, action_url: "/v1/install/#{oauth_provider.key}/login")
        end
      end
    end

    resource :front do
      post :webhook do
        is_initial_request = request.headers["X-Front-Challenge"].present?

        if is_initial_request
          whresp = Webhookdb::Front.initial_verification_request_response(request)
          s_status, s_headers, s_body = whresp.to_rack
          s_headers.each { |k, v| header k, v }
          if s_headers["Content-Type"] == "application/json"
            body Oj.load(s_body)
          else
            env["api.format"] = :binary
            body s_body
          end
          status s_status
        else
          # In cases where there is a change to a message, the event payload will have a "target" object and that object
          # will have a "type" of "message". In cases where there is a change to a conversation, there will be no
          # "target" object. In these cases the conversation resource is in the event as the "conversation" object.
          target_type = params.dig(:payload, :target, :_meta, :type) || "conversation"
          service_name = "front_#{target_type}_v1"

          resource_url = params.dig(:payload, :_links, :self)
          api_url = resource_url.nil? ? nil : URI.parse(resource_url).host
          root_sint = Webhookdb::ServiceIntegration[service_name: "front_marketplace_root_v1", api_url:]
          if root_sint.nil?
            logger.warn "front_webhook_unregistered_app", front_api_url: api_url
            status 200
            present({message: "unregistered app"})
          else
            handling_sint = root_sint&.recursive_dependents&.find do |d|
              d.service_name == service_name
            end
            if handling_sint.nil?
              logger.warn "front_webhook_invalid_topic", front_api_url: api_url, front_topic: target_type
              status 200
              present({message: "invalid topic"})
            else
              handle_webhook_request(handling_sint.opaque_id) do
                handling_sint
              end
            end
          end
        end
      end
    end
  end
end
