# frozen_string_literal: true

require "webhookdb/api"
require "webhookdb/custom_query"

class Webhookdb::API::CustomQueries < Webhookdb::API::V1
  resource :organizations do
    route_param :org_identifier do
      resource :custom_queries do
        helpers do
          def lookup!
            org = lookup_org!
            # We can add other identifiers in the future
            cq = org.custom_queries_dataset[opaque_id: params[:query_identifier]]
            merror!(403, "There is no saved query with that identifier.") if cq.nil?
            return cq
          end

          def guard_editable!(customer, cq)
            return if customer === cq.created_by
            return if has_admin?(cq.organization, customer:)
            permission_error!("You must be the query's creator or an org admin.")
          end

          def execute_readonly_query_with_suggestion(org, sql)
            r, message = execute_readonly_query(org, sql)
            return r, nil unless r.nil?
            msg = "Something went wrong running your query. Perhaps a table it depends on was deleted. " \
                  "Check out #{Webhookdb::CustomQuery::DOCS_URL} for troubleshooting tips. " \
                  "Here's what went wrong: #{message}"
            return r, msg
          end
        end

        desc "Returns a list of all custom queries associated with the org."
        get do
          queries = lookup_org!.custom_queries
          message = ""
          if queries.empty?
            message = "This organization doesn't have any saved queries yet.\n" \
                      "Use `webhookdb saved-query create` to set one up."
          end
          present_collection queries, with: CustomQueryEntity, message:
        end

        desc "Creates a custom query."
        params do
          optional :description, type: String, prompt: "What is the query used for? "
          optional :sql, type: String, prompt: "Enter the SQL you would like to run: "
          optional :public, type: Boolean
        end
        post :create do
          cust = current_customer
          org = lookup_org!
          _, errmsg = execute_readonly_query_with_suggestion(org, params[:sql])
          if errmsg
            Webhookdb::API::Helpers.prompt_for_required_param!(
              request,
              :sql,
              "Enter a new query:",
              output: "That query was invalid. #{errmsg}\n" \
                      "You can iterate on your query by connecting to your database from any SQL editor.\n" \
                      "Use `webhookdb db connection` to get your query string.",
            )
          end
          cq = Webhookdb::CustomQuery.create(
            description: params[:description],
            sql: params[:sql],
            organization: org,
            created_by: cust,
            public: params[:public] || false,
          )
          message = "You have created a new saved query with an id of '#{cq.opaque_id}'. " \
                    "You can run it through the CLI, or through the API with or without authentication. " \
                    "See #{Webhookdb::CustomQuery::DOCS_URL} for more information."
          status 200
          present cq, with: CustomQueryEntity, message:
        end

        desc "Returns the query with the given identifier."
        params do
          optional :query_identifier, type: String, prompt: "What query would you like to see? "
        end
        get :lookup do
          cq = lookup!
          status 200
          message = "See #{Webhookdb::CustomQuery::DOCS_URL} to see how to run or modify your query."
          present cq, with: CustomQueryEntity, message:
        end

        desc "Runs the query with the given identifier."
        params do
          optional :query_identifier, type: String, prompt: "What query would you like to run? "
        end
        get :run do
          _customer = current_customer
          org = lookup_org!
          cq = lookup!
          r, msg = execute_readonly_query_with_suggestion(org, cq.sql)
          merror!(400, msg) if r.nil?
          status 200
          present({rows: r.rows, headers: r.columns, max_rows_reached: r.max_rows_reached})
        end

        desc "Updates the field on a custom query."
        params do
          optional :query_identifier, type: String, prompt: "What query would you like to update? "
          optional :field, type: String, prompt: "What field would you like to update (one of: " \
                                                 "#{Webhookdb::CustomQuery::CLI_EDITABLE_FIELDS.join(', ')}): "
          optional :value, type: String, prompt: "What is the new value? "
        end
        post :update do
          customer = current_customer
          cq = lookup!
          guard_editable!(customer, cq)
          # Instead of specifying which values are valid for the optional `field` param in the param declaration,
          # we do the validation here so that we can provide a more helpful error message
          unless Webhookdb::CustomQuery::CLI_EDITABLE_FIELDS.include?(params[:field])
            merror!(400, "That field is not editable.")
          end
          value = params[:value]
          case params[:field]
            when "public"
              begin
                value = Webhookdb.parse_bool(value)
              rescue ArgumentError => e
                Webhookdb::API::Helpers.prompt_for_required_param!(
                  request,
                  :value,
                  e.message + "\nAny boolean-like string (true, false, yes, no, etc) will work:",
                )
              end
              cq.public = value
            when "sql"
              r, msg = execute_readonly_query_with_suggestion(cq.organization, value)
              if r.nil?
                Webhookdb::API::Helpers.prompt_for_required_param!(
                  request,
                  :value,
                  "Enter your query:",
                  output: msg,
                )
              end
              cq.sql = value
            else
              cq.send(:"#{params[:field]}=", value)
          end
          cq.save_changes
          status 200
          message = "You have updated saved query #{cq.opaque_id} with #{params[:field]} set to #{value}"
          present cq, with: CustomQueryEntity, message:
        end

        params do
          optional :query_identifier, type: String, prompt: "What query would you like to delete? "
        end
        post :delete do
          customer = current_customer
          cq = lookup!
          guard_editable!(customer, cq)
          cq.destroy
          status 200
          present cq, with: CustomQueryEntity,
                      message: "You have successfully deleted the saved query '#{cq.description}'."
        end
      end
    end
  end

  resource :custom_queries do
    route_param :query_identifier, type: String do
      get :run do
        # This endpoint can be used publicly, so should expose as little information as possible.
        # Do not expose permissions or query details.
        # _customer = current_customer
        # org = lookup_org!
        # cq = lookup!
        cq = Webhookdb::CustomQuery[opaque_id: params[:query_identifier]]
        forbidden! if cq.nil?
        if cq.private?
          authed = Webhookdb::API::ConnstrAuth.find_authed([cq.organization], request)
          if !authed && (cust = current_customer?)
            authed = !cust.verified_memberships_dataset.where(organization: cq.organization).empty?
            end
          forbidden! unless authed
        end
        r, _ = execute_readonly_query(cq.organization, cq.sql)
        merror!(400, "Something went wrong running the query.") if r.nil?
        status 200
        present({rows: r.rows, headers: r.columns, max_rows_reached: r.max_rows_reached})
      end
    end
  end

  class CustomQueryEntity < Webhookdb::API::BaseEntity
    expose :opaque_id, as: :id
    expose :description
    expose :sql
    expose :public

    def self.display_headers
      return [[:opaque_id, "Id"], [:description, "Description"], [:sql, "Sql"], [:public, "Public"]]
    end
  end
end
