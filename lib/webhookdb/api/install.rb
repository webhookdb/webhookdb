# frozen_string_literal: true

require "webhookdb/api"
require "webhookdb/oauth"
require "webhookdb/service/view_api"
require "webhookdb/front"

class Webhookdb::API::Install < Webhookdb::API::V1
  include Webhookdb::Service::ViewApi

  namespace :install do
    helpers do
      def lookup_session!
        session = Webhookdb::Oauth::Session.usable.where(oauth_state: params[:state]).first
        error!("Forbidden", 302, {"Location" => "/v1/install/#{oauth_provider.key}/forbidden"}) if session.nil?
        return session
      end

      def handle_login(email:, session:, action_url:)
        begin
          new_customer, me = Webhookdb::Customer.find_or_create_for_email(email)
        rescue Sequel::ValidationFailed => e
          raise FormError.new(e.message.capitalize, 400)
        end
        me.reset_codes_dataset.usable.each(&:expire!)
        me.add_reset_code(transport: "email")
        session.update(customer: me)
        rendered = render_liquid(
          "messages/web/install-customer-login.liquid",
          serialize_view_params: true,
          vars: {
            app_name: oauth_provider.app_name,
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
        return me if me.should_skip_authentication?
        begin
          Webhookdb::Customer::ResetCode.use_code_with_token(otp_token) do |code|
            raise Webhookdb::Customer::ResetCode::Unusable unless code.customer === me
          end
        rescue Webhookdb::Customer::ResetCode::Unusable
          raise FormError.new("Sorry, that token is invalid. Please try again.", 403)
        end
        return me
      end
    end

    params do
      requires :state, type: String
    end
    get :fake_oauth_authorization do
      redirect "/v1/install/fake/callback?code=fakecode&state=#{params[:state]}"
    end

    route_param :oauth_provider, type: String, values: Webhookdb::Oauth.registry.keys do
      helpers do
        def oauth_provider
          @oauth_provider ||= Webhookdb::Oauth.provider(params[:oauth_provider])
        rescue KeyError
          forbidden!
        end

        def exchange_authorization_code(code)
          return oauth_provider.exchange_authorization_code(code:)
        rescue Webhookdb::Http::Error => e
          logger.warn "oauth_exchange_error", exception: e
          url = "#{Webhookdb.api_url}/v1/install/#{oauth_provider.key}"
          raise FormError.new(
            "Something went wrong getting your access token from #{oauth_provider.app_name}. " \
            "Please start over by going to <a href=\"#{url}\">#{url}</a>.",
            400,
          )
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
        Webhookdb::Oauth::Session.create(
          oauth_state:,
          **Webhookdb::Oauth::Session.params_for_request(request),
        )
        auth_url = oauth_provider.authorization_url(state: oauth_state)
        redirect auth_url
      end

      params do
        requires :code, type: String, desc: "Authorization code that we exchange for tokens."
        requires :state, type: String, desc: "The user session info string that we provided to the oauth flow."
      end
      get :callback do
        session = lookup_session!
        code = params[:code]
        # Exchange the token now, in case it's invalid we don't want to find out at the end.
        tokens = exchange_authorization_code(code)
        session.update(token_json: tokens.as_json)
        # Send the user to auth. We could (and did) use a "/me" endpoint here
        # to get an email, but that pushes the trust someone is who they say they are
        # to the oauth provider. We don't feel comfortable doing that in all cases,
        # so we ask them to auth with WebhookDB.
        #
        # On top of that, many setups don't have a way to know who did the connection,
        # nor can we be sure what org to install the replicators into,
        # so may as well put everyone on the same path.
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
            app_name: oauth_provider.app_name,
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
        if (otp_token = params[:otp_token]).nil?
          # This is the first submit, asking for email. Prompt them for an OTP.
          handle_login(email:, session:, action_url: "/v1/install/#{oauth_provider.key}/login")
        else
          # This is the 'second' submit, asking for OTP.
          # Verify it, ensure the customer has a default org, and then send them to the 'org chooser'.
          # Order of operations here is:
          # - Verify the OTP
          # - Make sure we can find a valid admin membership
          # - Only then do we exchange the token.
          # - Setup replicators.
          session.db.transaction do
            customer = find_and_verify_user(email:, otp_token:)
            Webhookdb::Customer.find_or_create_default_organization(customer)
            session.update(customer:)
          end
          redirect "/v1/install/#{oauth_provider.key}/org?state=#{session.oauth_state}"
        end
      end

      params do
        requires :state, type: String
      end
      get :org do
        session = lookup_session!
        organizations = session.customer.verified_memberships.select(&:admin?).map do |m|
          {name: m.organization.name, key: m.organization.key, checked: m.default? ? "true" : ""}
        end
        rendered = render_liquid(
          "messages/web/install-org-chooser.liquid",
          serialize_view_params: true,
          vars: {
            app_name: oauth_provider.app_name,
            action_url: "/v1/install/#{oauth_provider.key}/org",
            oauth_state: session.oauth_state,
            organizations:,
          },
        )
        status 200
        body rendered
      end

      params do
        requires :state, type: String, desc: "the user session info string that we provided to Front"
        optional :existing_org_key, type: String
        optional :new_org_name, type: String
      end
      post :org do
        session = lookup_session!
        if (key = params[:existing_org_key]).present?
          membership = session.customer.verified_memberships_dataset.
            admin.
            where(organization: Webhookdb::Organization.where(key:)).
            first
          raise FormError.new("You are not an administrator of that org or it does not exist.", 400) if
            membership.nil?
        elsif (name = params[:new_org_name])
          org = Webhookdb::Organization.create_if_unique(name:)
          raise FormError.new("Sorry, an organization with that name already exists.", 400) if
            org.nil?
          membership = session.customer.add_membership(
            organization: org,
            membership_role: Webhookdb::Role.admin_role,
            verified: true,
          )
        else
          raise FormError.new("Existing organization key or a new organization name are required", 400)
        end

        tokens = Webhookdb::Oauth::Tokens.new(**session.token_json)
        session.db.transaction do
          session.customer.replace_default_membership(membership)
          membership.organization.prepare_database_connections?
          oauth_provider.build_marketplace_integrations(organization: membership.organization, tokens:)
          session.update(organization: membership.organization, token_json: nil)
          redirect "/v1/install/#{oauth_provider.key}/success?state=#{params[:state]}"
        end
      end

      params do
        requires :state, type: String
      end
      get :success do
        session = lookup_session!
        # Mark the session used on GET, since we use the state to look up the session.
        # It does mean that refreshing the page will error, though.
        session.update(used_at: Time.now)
        rendered = render_liquid(
          "messages/web/install-success.liquid",
          serialize_view_params: true,
          vars: {
            app_name: oauth_provider.app_name,
            database_url: session.organization.readonly_connection_url,
            supports_webhooks: oauth_provider.supports_webhooks?,
          },
        )
        status 200
        body rendered
      end

      get :forbidden do
        rendered = render_liquid(
          "messages/web/install-forbidden.liquid",
          vars: {
            app_name: oauth_provider.app_name,
            terminal_url: "#{Webhookdb.api_url}/terminal",
            install_url: "#{Webhookdb.api_url}/v1/install/#{oauth_provider.key}",
          },
        )
        status 403
        body rendered
      end
    end

    resource :front do
      post :webhook do
        is_initial_request = request.headers["X-Front-Challenge"].present?
        if is_initial_request
          whresp = Webhookdb::Front.initial_verification_request_response(request, Webhookdb::Front.app_secret)
          s_status, s_headers, s_body = whresp.to_rack
          s_headers.each { |k, v| header k, v }
          body Oj.load(s_body)
          status s_status
          break
        end

        resource_url = params.dig(:payload, :_links, :self)
        handle_webhook_request("front_marketplace_host-#{resource_url || '?'}") do
          if resource_url.nil?
            logger.warn "front_webhook_empty_resource_url"
            status 200
            present({message: "unregistered/empty app"})
            next :pass
          end

          # In cases where there is a change to a message, the event payload will have a "target" object and that object
          # will have a "type" of "message". In cases where there is a change to a conversation, there will be no
          # "target" object. In these cases the conversation resource is in the event as the "conversation" object.
          target_type = params.dig(:payload, :target, :_meta, :type) || "conversation"
          service_name = "front_#{target_type}_v1"
          api_url = URI.parse(resource_url).host
          unless (root_sint = Webhookdb::ServiceIntegration[service_name: "front_marketplace_root_v1", api_url:])
            logger.warn "front_webhook_unregistered_app", front_api_url: api_url
            status 200
            present({message: "unregistered app"})
            next :pass
          end

          handling_sint = root_sint.recursive_dependents.find { |d| d.service_name == service_name }
          if handling_sint.nil?
            logger.warn "front_webhook_invalid_topic", front_api_url: api_url, front_topic: target_type
            status 200
            present({message: "invalid topic"})
            next :pass
          end
          next handling_sint
        end
      end
    end

    resource :front_signalwire do
      params do
        requires :type, type: String, values: Webhookdb::Front::CHANNEL_EVENT_TYPES
        optional :payload, type: JSON
      end
      route [:post, :delete], :channel do
        handle_webhook_request("front-signalwire-channel") do
          auth_header = request.headers["Authorization"]
          merror!(401, "Missing Authorization header", code: "unauthenticated") if
            auth_header.nil?
          merror!(401, "Expected Bearer authorization", code: "unauthenticated") unless
            auth_header.start_with?("Bearer ")
          apikey = auth_header[7..]
          sint = Webhookdb::ServiceIntegration.for_api_key(apikey)
          merror!(401, "Invalid API key", code: "unauthenticated") if sint.nil?
          sint
        end
      end
    end

    resource :increase do
      params do
        requires :id, type: String
        requires :created_at, type: Time
        requires :category, type: String
        requires :associated_object_type, type: String
        requires :associated_object_id, type: String
        requires :type, type: String
      end
      post :webhook do
        group_id = env["HTTP_INCREASE_GROUP_ID"]
        handle_webhook_request("increase-group-#{group_id || '?'}") do
          if group_id.nil?
            # No group ID is one of our own events.
            # Run the job to handle it as a platform event (usually this is the oauth disconnect)
            Amigo.publish("increase.#{params[:category]}", declared(params).as_json)
            status 202
            present({message: "ok"})
            next :pass
          end
          root_sint = Webhookdb::ServiceIntegration[service_name: "increase_app_v1", api_url: group_id]
          if root_sint.nil?
            logger.error "increase_unregistered_group", increase_group_id: group_id
            status 202
            present({message: "unregistered group"})
            next :pass
          end
          next root_sint
        end
      end
    end

    resource :intercom do
      helpers do
        def find_root(app_id)
          return Webhookdb::ServiceIntegration[service_name: "intercom_marketplace_root_v1", api_url: app_id]
        end
      end
      post :webhook do
        # Because the `_webhook_response` function is always the same here, I'm wondering if it's even
        # advisable to do the integration lookup before performing a webhook verification when we don't
        # need that info. Something to consider upon refactor
        app_id = params[:app_id]
        root_sint = find_root(app_id)
        opaque_id = root_sint&.opaque_id || "intercom_marketplace_appid-#{app_id}"
        handle_webhook_request(opaque_id) do
          if root_sint.nil?
            logger.warn "intercom_webhook_unregistered_app", intercom_app_id: app_id
            status 200
            present({message: "unregistered app"})
            next :pass
          end
          # Notification topics are formatted like "{model}.{thing that happened}" (e.g. "contact.created")
          # to get the model type of the notification, for our purposes we can just grab that first chunk
          # This should probably move to the marketplace replicator itself,
          # rather than being done in the endpoint (see /v1/install/increase/webhook).
          type = params[:topic].split(".")[0]
          handling_type = "intercom_#{type}_v1"
          unless (handling_sint = root_sint.recursive_dependents.find { |d| d.service_name == handling_type })
            logger.warn "intercom_webhook_invalid_topic", intercom_app_id: app_id, intercom_topic: params[:topic]
            status 200
            present({message: "invalid topic"})
            next :pass
          end
          next handling_sint
        end
      end

      params do
        requires :app_id
      end
      post :uninstall do
        app_id = params[:app_id]
        root_sint = find_root(app_id)
        # Intercom uses X-Body-Signature rather than X-Hub-Signature here,
        # unlike the normal /webhook request.
        # I've asked Intercom if they can support X-Hub-Signature here as well.
        # If they cannot, we need to add support for the alternative signature validation.
        opaque_id = root_sint&.opaque_id || "intercom_marketplace_appid-#{app_id}"
        handle_webhook_request(opaque_id) do
          root_sint&.destroy_self_and_all_dependents
          status 200
          present({o: "k"})
          next :pass
        end
      end

      params do
        # This endpoint recieves a value called "workspace_id" but it is
        # identical to the "app_id" value we get from the `/me` endpoint.
        # It just has a different name here for some reason.
        requires :workspace_id
      end
      post :health do
        # https://developers.intercom.com/docs/build-an-integration/learn-more/installation-health-check
        result = {}
        if find_root(params[:workspace_id]).nil?
          result[:state] = "UNHEALTHY"
          result[:cta_type] = "REINSTALL_CTA"
          result[:message] = "You need to reinstall this app to sync your data to WebhookDB."
        else
          result[:state] = "OK"
        end
        status 200
        present result
      end
    end
  end
end
