# frozen_string_literal: true

require "webhookdb/api"

class Webhookdb::API::SavedViews < Webhookdb::API::V1
  resource :organizations do
    route_param :org_identifier do
      resource :saved_views do
        helpers do
          def lookup_view!
            org = lookup_org!
            cq = org.saved_views_dataset[name: params[:name].strip]
            merror!(403, "There is no view with that name.") if cq.nil?
            return cq
          end

          def guard_editable!(customer, org)
            return if has_admin?(org, customer:)
            permission_error!("You must be an org admin to modify views.")
          end
        end

        desc "Returns a list of all saved views associated with the org."
        get do
          views = lookup_org!.saved_views
          message = ""
          if views.empty?
            message = "This organization doesn't have any saved views yet.\n" \
                      "Use `webhookdb saved-view create` to set one up."
          end
          present_collection views, with: SavedViewEntity, message:
        end

        desc "Creates or replaces the view with the given name."
        params do
          optional :name,
                   type: String,
                   prompt: "Enter the view name (alphanumeric, spaces, underscores):"
          optional :sql, type: String, prompt: "Enter the SQL you would like to run:"
        end
        post :create_or_replace do
          cust = current_customer
          org = lookup_org!
          check_feature_access!(org, Webhookdb::SavedView.feature_role)
          guard_editable!(cust, org)
          begin
            sv = Webhookdb::SavedView.create_or_replace(
              organization: org,
              sql: params[:sql],
              name: params[:name].strip,
              created_by: cust,
            )
          rescue Webhookdb::SavedView::InvalidQuery => e
            Webhookdb::API::Helpers.prompt_for_required_param!(
              request,
              :sql,
              "Enter a new query:",
              output: "That query was invalid. #{e.message}\n" \
                      "You can iterate on your query by connecting to your database from any SQL editor.\n" \
                      "Use `webhookdb db connection` to get your query string.",
            )
          rescue Webhookdb::DBAdapter::InvalidIdentifier => e
            Webhookdb::API::Helpers.prompt_for_required_param!(
              request,
              :name,
              "Enter a new name:",
              output: e.message,
            )
          end
          message = "You have created or replaced the view with the name '#{sv.name}'. " \
                    "You can now use it in any query with your database connection string. " \
                    "Run `webhookdb db connection` to retrieve your connection string if you need it."
          status 200
          present sv, with: SavedViewEntity, message:
        end

        post :delete do
          customer = current_customer
          cq = lookup_view!
          guard_editable!(customer, cq.organization)
          cq.destroy
          status 200
          present cq, with: SavedViewEntity,
                      message: "You have successfully deleted the saved view '#{cq.name}'."
        end
      end
    end
  end

  class SavedViewEntity < Webhookdb::API::BaseEntity
    expose :name

    def self.display_headers
      return [[:name, "Name"]]
    end
  end
end
