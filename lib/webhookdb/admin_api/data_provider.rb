# frozen_string_literal: true

require "webhookdb/admin_api"

class Webhookdb::AdminAPI::DataProvider < Webhookdb::AdminAPI::V1
  include Webhookdb::AdminAPI::Entities

  TYPEINFO = {
    backfill_jobs: [Webhookdb::BackfillJob, BackfillJob],
    customers: [Webhookdb::Customer, Customer],
    customer_reset_codes: [Webhookdb::Customer::ResetCode, CustomerResetCode],
    logged_webhooks: [Webhookdb::LoggedWebhook, LoggedWebhook],
    message_bodies: [Webhookdb::Message::Body, MessageBody],
    message_deliveries: [Webhookdb::Message::Delivery, MessageDelivery],
    organization_database_migrations: [Webhookdb::Organization::DatabaseMigration, OrganizationDatabaseMigration],
    organization_memberships: [Webhookdb::OrganizationMembership, OrganizationMembership],
    organizations: [Webhookdb::Organization, Organization],
    roles: [Webhookdb::Role, Role],
    saved_queries: [Webhookdb::SavedQuery, SavedQuery],
    saved_views: [Webhookdb::SavedView, SavedView],
    service_integrations: [Webhookdb::ServiceIntegration, ServiceIntegration],
    subscriptions: [Webhookdb::Subscription, Subscription],
    sync_targets: [Webhookdb::SyncTarget, SyncTarget],
    webhook_subscriptions: [Webhookdb::WebhookSubscription, WebhookSubscription],
    webhook_subscription_deliveries: [Webhookdb::WebhookSubscription::Delivery, WebhookSubscriptionDelivery],
  }.freeze

  TYPES_FOR_RESOURCES = TYPEINFO.transform_values { |v| v[0] }.freeze
  ENTITIES_FOR_TYPES = TYPEINFO.values.to_h { |v| [v[0], v[1]] }.freeze

  resource :data_provider do
    helpers do
      params :data_provider_pagination do
        requires :page, type: Integer
        requires :per_page, type: Integer
      end

      params :data_provider_sort do
        requires :field, type: Symbol
        requires :order, type: Symbol, values: [:ASC, :DESC]
      end

      params :base_params do
        requires :resource, type: Symbol, values: TYPES_FOR_RESOURCES.keys
        optional :meta, type: JSON
      end

      params :base_record_params do
        use :base_params
        requires :id, type: Integer
      end

      params :list_params do
        use :base_params
        optional :pagination, type: JSON do
          use :data_provider_pagination
        end
        optional :sort, type: JSON do
          use :data_provider_sort
        end
        optional :filter, type: JSON
      end

      params :many_ids_params do
        use :base_params
        requires :ids, type: [Integer]
      end

      def lookup_model_type
        rt = TYPES_FOR_RESOURCES.fetch(params.fetch(:resource))
        return rt
      end

      def lookup_model
        cls = lookup_model_type
        m = cls[id: params.fetch(:id)]
        merror!(403, "No #{params[:resource]} with pk #{params[:id]}", code: "forbidden") if m.nil?
        return m
      end

      def lookup_entity(cls)
        return ENTITIES_FOR_TYPES.fetch(cls)
      end

      def present_one(item, item_entity)
        data = item_entity.represent(item)
        e = {data:}
        present e
      end

      def present_dataset(ds, item_entity)
        data = ds.all.map { |o| item_entity.represent(o) }
        total = ds.respond_to?(:pagination_record_count) ? ds.pagination_record_count : ds.limit(nil).offset(nil).count
        e = {data:, total:}
        present e
      end

      def apply_list_params(ods)
        ds = ods
        if (filter = params[:filter])
          search_term = filter.delete(:q)
          ds = ds.text_search(search_term) if search_term && ds.respond_to?(:text_search)
          ds = ds.where(filter.to_h.transform_keys(&:to_sym)) if filter.present?
        end
        if (sort = params[:sort])
          sort_col = sort[:field]
          unless sort_col.to_s.include?(".")
            order = Sequel.send(sort[:order].to_s.downcase, sort_col)
            ds = ds.order(order)
          end
        else
          ds = ds.order(Sequel.desc(:id))
        end
        if (pagination = params[:pagination])
          ds = ds.paginate(pagination[:page], pagination[:per_page])
        end
        return ds
      end
    end

    params do
      use :base_record_params
    end
    post :get_one do
      model = lookup_model
      status 200
      present_one model, lookup_entity(model.class)
    end

    params do
      use :list_params
    end
    post :get_list do
      model_cls = lookup_model_type
      ds = model_cls.dataset
      ds = apply_list_params(ds)
      status 200
      present_dataset ds, lookup_entity(model_cls)
    end

    params do
      use :many_ids_params
    end
    post :get_many do
      model_cls = lookup_model_type
      ds = model_cls.dataset
      ds = ds.where(id: params.fetch(:ids))
      status 200
      present_dataset ds, lookup_entity(model_cls)
    end

    params do
      use :list_params
      requires :target, type: Symbol
      requires :id, type: Integer
    end
    post :get_many_reference do
      model_cls = lookup_model_type
      ds = model_cls.dataset
      ds = ds.where(params[:target] => params[:id])
      ds = apply_list_params(ds)
      status 200
      present_dataset ds, lookup_entity(model_cls)
    end
  end
end
