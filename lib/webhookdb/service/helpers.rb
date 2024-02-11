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
  # - if we have an admin, but they should not be (deleted or missing role), throw unauthed error.
  # - if current user is nil, return nil, since the caller can handle it.
  # - if current user is deleted and there is no admin, throw unauthed error.
  # - if current user is deleted and admin is deleted, throw unauthed error.
  # - otherwise, return current user.
  #
  # The scenarios this covers are:
  # - Normal users cannot auth if deleted.
  # - Admins can sudo deleted users, and current_customer still works.
  # - Deleted admins cannot auth or get their sudo'ed user.
  #
  # NOTE: It is safe to throw unauthed errors for deleted users-
  # this does not expose whether a user exists or not,
  # because the only way to call this is via cookies,
  # and cookies are encrypted. So it is impossible to force requests
  # trying to auth/check auth for a user without knowing the secret.
  def _check_customer_deleted(user, potential_admin)
    return nil if user.nil?
    if potential_admin && (potential_admin.soft_deleted? || !potential_admin.roles.include?(Webhookdb::Role.admin_role))
      delete_session_cookies
      unauthenticated!
    end
    if user.soft_deleted? && potential_admin.nil?
      delete_session_cookies
      unauthenticated!
    end
    return user
  end

  def delete_session_cookies
    # Nope, cannot do this through Warden easily.
    # And really we should have server-based sessions we can expire,
    # but in the meantime, stomp on the cookie hard.
    options = env[Rack::RACK_SESSION_OPTIONS]
    options[:drop] = true
    # Rack sends a cookie with an empty session, but let's tell the browser to actually delete the cookie.
    cookies.delete(Webhookdb::Service::SESSION_COOKIE, domain: options[:domain], path: options[:path])
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
    permission_error!("Sorry, this action is unavailable.")
  end

  def merror!(status, message, code: nil, more: {}, headers: {}, rollback_db: nil, alert: false)
    header "Content-Type", "application/json"
    body = Webhookdb::Service.error_body(status, message, code:, more:)
    if alert
      Sentry.with_scope do |scope|
        scope&.set_extras(**body)
        Sentry.capture_message(message)
      end
    end
    if rollback_db
      Webhookdb::Postgres.defer_after_rollback(rollback_db) do
        error!(body, status, headers)
      end
      raise Sequel::Rollback
    else
      error!(body, status, headers)
    end
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

  def permission_error!(message)
    merror!(403, message, code: "permission_check")
  end

  def check_feature_access!(org, role)
    return if org.feature_roles.include?(role)
    permission_error!("This feature is not enabled for your organization.")
  end

  # Raise a 400 error for unstructured validation.
  # @param errors [Array<String>,String] Error messages, like 'password is invalid'.
  # @param message [String] If not given, build it from the errors list.
  def invalid!(errors, message: nil)
    errors = [errors] unless errors.respond_to?(:to_ary)
    message ||= errors.join(", ").upcase_first
    merror!(400, message, code: "validation_error", more: {errors:, field_errors: {}})
  end

  # Raise a 400 error for structured validation.
  # @param field_errors [Hash<String, Array<String>>] If errors are tied to fields,
  #   this is a hash where the key is the field name, and the value is an array of all validation messages.
  #   For example, {password: ['is invalid']}
  # @param message [String] If not given, build it from the errors list.
  def invalid_fields!(field_errors, message: nil)
    errors = field_errors.map { |field, field_errs| field_errs.map { |e| "#{field} #{e}" } }.flatten
    message ||= errors.join(", ").upcase_first
    merror!(400, message, code: "validation_error", more: {errors:, field_errors:})
  end

  def endpoint_removed!
    merror!(
      403,
      "Sorry, this endpoint has been removed. Run `webhookdb update` to upgrade your CLI, " \
      "or file a ticket at #{Webhookdb.oss_repo_url} for help.",
      code: "endpoint_removed",
    )
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
      invalid_fields!(object.errors.to_h)
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

  # Set the provided, declared/valid parameters in params on model.
  # Because Grape's `declared()` function *adds* parameters that are declared-but-not-provided,
  # and its `params` value includes provided-but-not-declared entries,
  # the fields we set are the intersection of the two.
  def set_declared(model, params, ignore: [:id])
    # If .to_h is used (rather than Grape's 'params' which is HashWithIndifferentAccess),
    # the keys may be strings. We need to deep symbolize since nested hashes get to_h with 'symbolize_keys'.
    params = params.deep_symbolize_keys
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
