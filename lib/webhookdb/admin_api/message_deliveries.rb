# frozen_string_literal: true

require "grape"

require "webhookdb/admin_api"

class Webhookdb::AdminAPI::MessageDeliveries < Webhookdb::AdminAPI::V1
  helpers do
    def lookup_delivery(params)
      (batch = Webhookdb::Message::Delivery[params[:id]]) or not_found!
      return batch
    end
  end

  resource :message_deliveries do
    desc "Return all message deliveries, newest first"
    params do
      use :pagination
      use :ordering, model: Webhookdb::Message::Delivery
      use :searchable
    end
    get do
      ds = Webhookdb::Message::Delivery.dataset
      if (to_like = search_param_to_sql(params, :to))
        criteria = to_like | search_param_to_sql(params, :template)
        ds = ds.where(criteria)
      end
      ds = order(ds, params)
      ds = paginate(ds, params)
      present_collection ds, with: Webhookdb::AdminAPI::MessageDeliveryEntity
    end

    desc "Return the delivery with the last ID"
    get :last do
      delivery = Webhookdb::Message::Delivery.last
      present delivery, with: Webhookdb::AdminAPI::MessageDeliveryWithBodiesEntity
    end

    route_param :id, type: Integer do
      desc "Return the delivery"
      get do
        delivery = lookup_delivery(params)
        present delivery, with: Webhookdb::AdminAPI::MessageDeliveryWithBodiesEntity
      end
    end
  end

  resource :customers do
    route_param :id, type: Integer do
      resource :message_deliveries do
        desc "Return all message deliveries for customer the given customers, as recipients or to their emails"
        get do
          # rubocop:disable Layout/LineLength
          ds = Webhookdb::Message::Delivery.to_customers(Webhookdb::Customer.where(id: params[:id])).order(Sequel.desc(:id))
          # rubocop:enable Layout/LineLength
          present_collection ds, with: Webhookdb::AdminAPI::MessageDeliveryEntity
        end
      end
    end
  end
end
