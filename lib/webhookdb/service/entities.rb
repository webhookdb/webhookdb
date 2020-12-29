# frozen_string_literal: true

require "grape_entity"

module Webhookdb::Service::Entities
  class Money < Grape::Entity
    expose :cents
    expose :currency do |obj|
      obj.currency.iso_code
    end
  end

  class TimeRange < Grape::Entity
    expose :begin, as: :start
    expose :end
  end

  class Base < Grape::Entity
    extend Webhookdb::MethodUtilities

    expose :object_type, as: :object, unless: ->(_, _) { self.object_type.nil? }

    # Override this on entities that are addressable on their own
    def object_type
      return nil
    end

    def self.delegate_to(*names, safe: false, safe_with_default: nil)
      return lambda do |instance|
        names.reduce(instance) do |memo, name|
          memo.send(name)
        rescue NoMethodError => e
          raise e unless safe || safe_with_default
          return safe_with_default
        end
      end
    end
  end

  class Image < Base
    expose :url
    expose :alt
  end

  class CurrentCustomer < Base
    expose :id
    expose :created_at
    expose :email
    expose :name
    expose :first_name
    expose :last_name
    expose :us_phone, as: :phone
    expose :email_verified?, as: :email_verified
    expose :phone_verified?, as: :phone_verified
    expose :onboarded?, as: :onboarded
    expose :roles do |instance|
      instance.roles.map(&:name)
    end
    expose :impersonated do |_instance, options|
      Webhookdb::Service::Auth::Impersonation.new(options[:env]["warden"]).is?
    end
  end

  # Add an 'etag' field to the rendered entity.
  # This should only be used on the root entity, and entities with etags should not be nested.
  # Usage:
  #
  #   class DashboardEntity < BaseEntity
  #     prepend Webhookdb::Service::Entities::EtaggedMixin
  #     expose :my_field
  #   end
  module EtaggedMixin
    def to_json(*)
      serialized = super
      raise TypeError, "EtaggedMixin can only be used for object entities" unless serialized[-1] == "}"
      etag = Digest::MD5.hexdigest(Webhookdb::VERSION.to_s + serialized)
      return serialized[...-1] + ",\"etag\":\"#{etag}\"}"
    end
  end
end
