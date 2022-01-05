# -*- ruby -*-
# frozen_string_literal: true

require "appydays/loggable"
require "grape"

require "webhookdb/service" unless defined?(Webhookdb::Service)
require "webhookdb/service/collection"

# A collection of helper functions that can be included
module Webhookdb::Service::Helpers
  extend Grape::API::Helpers
  include Webhookdb::Service::Collection::Helpers

  def logger
    return Webhookdb::Service.logger
  end

  # Return the currently-authenticated user,
  # or respond with a 401 if there is no authenticated user.
  def current_customer
    return _check_customer_deleted(env["warden"].authenticate!(scope: :customer), admin_customer?)
  end

  # Return the currently-authenticated user,
  # or respond nil if there is no authenticated user.
  def current_customer?
    return _check_customer_deleted(env["warden"].user(scope: :customer), admin_customer?)
  end

  def admin_customer
    return _check_customer_deleted(env["warden"].authenticate!(scope: :admin), nil)
  end

  def admin_customer?
    return _check_customer_deleted(env["warden"].authenticate(scope: :admin), nil)
  end

  def authenticate!
    warden = env["warden"]
    user = warden.authenticate!(scope: :customer)
    warden.set_user(user, scope: :admin) if user.admin?
    return user
  end

  # Handle denying authentication if the given user cannot auth.
  # That is:
  # - if current user is nil, return nil, since the caller can handle it.
  # - if current user is deleted and there is no admin, throw unauthed error.
  # - if current user is deleted and admin is deleted, throw unauthed error.
  # - otherwise, return current user.
  #
  # The scenarios this covers are:
  # - Normal users cannot auth if deleted.
  # - Admins can sudo deleted users, and current_customer still works.
  # - Deleted admins cannot auth or get their sudo'ed user.
  def _check_customer_deleted(user, potential_admin)
    return nil if user.nil?
    unauthenticated! if user.soft_deleted? && (potential_admin.nil? || potential_admin.soft_deleted?)
    return user
  end

  def set_customer(customer)
    warden = env["warden"]
    warden.set_user(customer, scope: :customer)
    warden.set_user(customer, scope: :admin) if customer.admin?
  end

  def current_session_id
    return env["rack.session"].id
  end

  def check_role!(customer, role_name)
    has_role = customer.roles.find { |r| r.name == role_name }
    return if has_role
    role_exists = !Webhookdb::Role.where(name: role_name).empty?
    raise "The role '#{role_name}' does not exist so cannot be checked. You need to create it first." unless role_exists
    merror!(403, "Sorry, this action is unavailable.", code: "role_check")
  end

  def merror!(status, message, code: nil, more: {}, headers: {})
    header "Content-Type", "application/json"
    body = Webhookdb::Service.error_body(status, message, code: code, more: more)
    error!(body, status, headers)
  end

  def unauthenticated!
    merror!(401, "Unauthenticated", code: "unauthenticated")
  end

  def unauthenticated_with_message!(msg)
    env["webhookdb.authfailuremessage"] = msg
    unauthenticated!
  end

  def forbidden!
    merror!(403, "Forbidden", code: "forbidden")
  end

  def not_found!
    merror!(404, "Not Found", code: "not_found")
  end

  def invalid!(errors, message: nil)
    errors = [errors] unless errors.respond_to?(:to_ary)
    message ||= errors.join(", ")
    message = message.first.upcase + message[1..]
    merror!(400, message, code: "validation_error", more: {errors: errors})
  end

  def search_param_to_sql(params, column, param: :search)
    search = params[param]&.strip
    return nil if search.blank? || search == "*"
    term = "%#{search.strip}%"
    return Sequel.ilike(column, term)
  end

  ### If +object+ is valid, save and return it.
  ### If not, call invalid! witht the validation errors.
  def save_or_error!(object)
    if object.valid?
      object.save_changes
      return object
    else
      invalid!(object.errors.full_messages)
    end
  end

  def paginate(dataset, params)
    return dataset.paginate(params[:page], params[:per_page])
  end

  def order(dataset, params)
    expr = params[:order_direction] == :asc ? Sequel.asc(params[:order_by]) : Sequel.desc(params[:order_by])
    return dataset.order(expr, Sequel.desc(:id))
  end

  def use_http_expires_caching(expiration)
    return unless Webhookdb::Service.endpoint_caching
    header "Cache-Control", "public"
    header "Expires", expiration.from_now.httpdate
  end

  def render_liquid(data_rel_path, vars: {}, content_type: "text/html")
    tmpl_file = File.open(Webhookdb::DATA_DIR + data_rel_path)
    liquid_tmpl = Liquid::Template.parse(tmpl_file.read)
    rendered = liquid_tmpl.render!(vars.stringify_keys, registers: {})
    content_type content_type
    env["api.format"] = :binary
    return rendered
  end

  # Set the provided, declared/valid parameters in params on model.
  # Because Grape's `declared()` function *adds* parameters that are declared-but-not-provided,
  # and its `params` value includes provided-but-not-declared entries,
  # the fields we set are the intersection of the two.
  def set_declared(model, params, ignore: [:id])
    decl = declared_and_provided_params(params, exclude: ignore)
    ignore.each { |k| decl.delete(k) }
    decl.delete_if { |k| !params.key?(k) }
    model.set(decl)
  end

  def declared_and_provided_params(params, exclude: [])
    decl = declared(params)
    exclude.each { |k| decl.delete(k) }
    decl.delete_if { |k| !params.key?(k) }
    return decl
  end

  params :money do
    requires :cents, type: Integer
    optional :currency, type: String, default: "USD"
  end

  params :time_range do
    requires :start, as: :begin, type: Time
    requires :end, type: Time
  end

  params :pagination do
    optional :page, type: Integer, default: 1
    optional :per_page, type: Integer, default: 100
  end

  params :searchable do
    optional :search, type: String
  end

  params :order do |options|
    optional :order_by, type: Symbol, values: options[:order_by], default: options[:default_order_by]
    optional :order, type: Symbol, values: [:asc, :desc], default: options[:default_order]
  end

  params :ordering do |options|
    default_order_by = options[:default] || :created_at
    order_by_values = options[:values] || options[:model]&.columns
    raise "Must provide :values or :model for possible orderings" unless order_by_values
    optional :order_by, type: Symbol, values: order_by_values, default: default_order_by
    optional :order_direction, type: Symbol, values: [:asc, :desc], default: :desc
  end

  params :address do
    optional :address1, type: String, allow_blank: false
    optional :address2, type: String
    optional :city, type: String, allow_blank: false
    optional :state_or_province, type: String, allow_blank: false
    optional :postal_code, type: String, allow_blank: false
    all_or_none_of :address1, :city, :state_or_province, :postal_code
    optional :lat, type: Float
    optional :lng, type: Float
  end
end
