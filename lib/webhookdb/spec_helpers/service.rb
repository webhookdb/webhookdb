# frozen_string_literal: true

require "appydays/loggable"
require "pathname"
require "rack/test"
require "rspec"
require "warden"
require "yajl"

require "webhookdb/spec_helpers"

module Webhookdb::SpecHelpers::Service
  def self.included(context)
    context.include(WebhookdbTestMethods)

    ::Warden.test_mode!

    super

    context.after(:each) { Warden.test_reset! }
  end

  def last_session_id
    (set_cookie = last_response["Set-Cookie"]) or return nil
    (session = Webhookdb::Service.decode_cookie(set_cookie)) or return nil
    return session["session_id"]
  end

  def login_as(customer, opts=nil)
    opts ||= {scope: :customer}
    Warden.on_next_request do |proxy|
      opts[:event] ||= :authentication
      proxy.set_user(customer, opts)
    end
  end

  def login_as_admin(customer, opts={})
    login_as(customer, opts.merge(scope: :customer))
    login_as(customer, opts.merge(scope: :admin))
  end

  def impersonate(admin: nil, target: nil)
    admin ||= Webhookdb::Fixtures.customer.admin.create
    target ||= Webhookdb::Fixtures.customer.create
    Warden.on_next_request do |proxy|
      proxy.set_user(admin, event: :authentication, scope: :admin)
      proxy.set_user(target, event: :authentication, scope: :customer)
      Webhookdb::Service::Auth::Impersonation.new(proxy).on(target)
    end
  end

  def logout(*scopes)
    Warden.on_next_request do |proxy|
      proxy.logout(*scopes)
    end
  end

  def fake_request(input: "", env: {})
    req = Rack::Request.new(env.merge({"rack.input" => Rewindable.new(input)}))
    return req
  end

  class Rewindable < String
    def initialize(s)
      super
      @s = s
    end

    def read(*)
      return @s
    end

    def rewind(*)
      nil
    end
  end

  class FakeSentryScope
    attr_accessor :user, :tags

    def initialize
      @user = {}
      @tags = {}
    end

    def set_user(user)
      @user.merge!(user)
    end

    def set_tags(tags)
      @tags.merge!(tags)
    end
  end

  # RSpec matcher for matching Rack::Test response body
  #
  # Expect that the response consists of JSON of some sort:
  #
  #   expect( last_response ).to have_json_body
  #
  # Expect that it's a JSON body that deserializes as an Object:
  #
  #   expect( last_response ).to have_json_body( Object )
  #   # -or-
  #   expect( last_response ).to have_json_body( Hash )
  #
  # Expect that it's a JSON body that deserializes as an Array:
  #
  #   expect( last_response ).to have_json_body( Array )
  #
  # Expect that it's a JSON body that deserializes as an Object that has
  # expected keys:
  #
  #   expect( last_response ).to have_json_body( Object ).
  #       that_includes( :id, :first_name, :last_name )
  #
  # Expect that it's a JSON body that deserializes as an Object that has
  # expected keys and values:
  #
  #   expect( last_response ).to have_json_body( Object ).
  #       that_includes(
  #           id: 118,
  #           first_name: 'Princess',
  #           last_name: 'Buttercup'
  #       )
  #
  # Expect that it's a JSON body that has other expected stuff:
  #
  #   expect( last_response ).to have_json_body( Object ).
  #       that_includes(
  #           last_name: a_string_matching(/humperdink/i),
  #           profile: a_hash_including(:age, :eyecolor, :tracking_ability)
  #       )
  #
  # Expect a JSON Array with objects that all match the criteria:
  #
  #   expect( last_response ).to have_json_body( Array ).
  #       of_lenth( 20 ).
  #       and( all( be_an(Integer) ) )
  #
  class HaveJSONBodyMatcher
    include Appydays::Loggable
    include RSpec::Matchers

    ### Create a new matcher that expects a response with a JSON body. If +expected_type+
    ### is not specified, any JSON body will be sufficient for a match.
    def initialize(expected_type=nil)
      @expected_type = expected_type
      @additional_expectations = []
      @response = nil
      @failure_description = nil
    end

    attr_reader :expected_type,
                :additional_expectations,
                :response,
                :failure_description

    ### RSpec matcher API -- returns +true+ if all expectations of the specified
    ### +response+ are met.
    def matches?(response)
      @response = response
      return self.correct_content_type? &&
          self.correct_json_type? &&
          self.matches_additional_expectations?
    rescue Yajl::ParseError => e
      return self.fail_with "Response has invalid JSON body: %s" % [e.message]
    end

    ### RSpec matcher API -- return a message describing an expectation failure.
    def failure_message
      return "\n---\n%s\n---\n\nReason: %s\n" % [
        self.pretty_print_response,
        self.failure_description,
      ]
    end

    ### RSpec matcher API -- return a message describing an expectation being met
    ### when the matcher was used in a negated context.
    def failure_message_when_negated
      msg = "expected response not to have a %s" % [self.describe_type_expectation]
      msg << " and " << self.describe_additional_expectations.join(", ") unless
        self.additional_expectations.emtpy?
      msg << ", but it did."

      return "\n---\n%s\n---\n\nReason: %s\n" % [
        self.pretty_print_response,
        msg,
      ]
    end

    ### Return the response's body parsed as JSON.
    def parsed_response_body
      return @parsed_response_body ||=
               Yajl::Parser.parse(self.response.body, check_utf8: true, symbolize_keys: true)
    end

    #
    # Mutators
    #

    ### Add an additional expectation that the JSON body contains the specified +members+.
    def that_includes(*memberset)
      @additional_expectations << include(*memberset)
      return self
    end
    alias which_includes that_includes

    ### Add an additional expectation that the JSON body does not contain the
    ### specified +members+.
    def that_excludes(*memberset)
      @additional_expectations << exclude(*memberset)
      return self
    end

    ### Add an additional expectation that the JSON body contain the specified
    ### +number+ of members.
    def of_length(number)
      @additional_expectations << have_attributes(length: number)
      return self
    end
    alias of_size of_length

    ### Add the specified +matchers+ as expectations of the Hash or Array that's
    ### parsed from the JSON body.
    def and(*matchers)
      @additional_expectations.concat(matchers)
      return self
    end

    ### Return a String that contains a pretty-printed version of the response object.
    protected def pretty_print_response
      return "%d %s HTTP/1.1\n%s\n\n%s" % [
        self.response.status,
        Rack::Utils::HTTP_STATUS_CODES[self.response.status],
        self.pretty_print_response_headers,
        self.pretty_print_response_body.encode("utf-8", invalid: :replace, undef: :replace),
      ]
    end

    ### Return a String that contains a pretty-printed version of the response headers.
    protected def pretty_print_response_headers
      return self.response.headers.map do |name, val|
        "%s: %s" % [name, val]
      end.join("\n")
    end

    ### Return a String that contains a pretty-printed version of the response body.
    protected def pretty_print_response_body
      return Yajl::Encoder.encode(@parsed_response_body, pretty: true, indent: "\t") if
        @parsed_response_body

      data = self.response.body
      return data ? data[0, 1000] : "(empty body)"
    end

    ### Return +false+ after setting the failure message to +message+.
    protected def fail_with(message)
      @failure_description = message
      self.logger.error "Failing with: %s" % [message]
      return false
    end

    ### Returns +true+ if the response has a JSON content-type header.
    protected def correct_content_type?
      content_type = self.response["content-type"]
      return self.fail_with "response doesn't have a Content-type header" unless content_type

      return fail_with "response's Content-type is %p" % [content_type] unless
        content_type.start_with?("application/json")

      return true
    end

    ### Return an Array of text describing the expectation that the body be an
    ### Object or an Array, if a type was expected. If no type was expected, returns
    ### an empty Array.
    protected def describe_type_expectation
      return case self.expected_type
          when Object, Hash
            "a JSON Object/Hash body"
          when Array
            "a JSON Array body"
          else
            "a JSON body"
        end
    end

    ### Check that the JSON body of the response has the correct type, if a type
    ### was specified.
    protected def correct_json_type?
      return self.parsed_response_body unless self.expected_type

      if self.expected_type == Array
        return self.fail_with("response body isn't a JSON Array") unless
          self.parsed_response_body.is_a?(Array)
      elsif self.expected_type == Object || self.expected_type == Hash
        return self.fail_with("response body isn't a JSON Object") unless
          self.parsed_response_body.is_a?(Hash)
      else
        warn "A valid JSON response can't be a %p!" % [self.expected_type]
      end

      return true
    end

    ### Return an Array of descriptions of the members that were expected to be included in the
    ### response body, if any were specified. If none were specified, returns an empty
    ### Array.
    protected def describe_additional_expectations
      return self.additional_expectations.map(&:description)
    end

    ### Check that any additional matchers registered via the `.and` mutator also
    ### match the parsed response body.
    protected def matches_additional_expectations?
      return self.additional_expectations.all? do |matcher|
        matcher.matches?(self.parsed_response_body) ||
            fail_with(matcher.failure_message)
      end
    end
  end

  class HaveStatusMatcher
    include RSpec::Matchers

    def initialize(expected_status)
      @expected_status = expected_status
    end

    def matches?(response)
      @response = response
      unless response.respond_to?(:status)
        raise "response has no .status method, did you pass in last_response.status " \
              "instead of last_response?"
      end
      return response.status == @expected_status
    end

    def failure_message
      parsed = self.parsed_body
      msg = "expected response status %d, got a %d response instead\n" % [@expected_status, @response.status]
      if parsed&.include?("error")
        suffix = +""
        if (errmsg = parsed["error"].delete("message"))
          suffix << ("\nMessage: %s" % [errmsg])
        end
        if (backtrace = parsed["error"].delete("backtrace"))
          suffix << ("\nBacktrace:\n%s" % [backtrace])
        end
        msg << ("Body: %s%s" % [parsed.to_json, suffix])
      else
        msg << ("Body: %s" % [@response.body])
      end
      return msg
    end

    protected def parsed_body
      return Yajl::Parser.parse(@response.body)
    rescue StandardError
      return nil
    end
  end

  # Matcher that will have a failure message if the response does not have the expected status.
  #
  #   expect( last_response ).to have_status( 200 )
  #
  module_function def have_status(expected_status)
    return HaveStatusMatcher.new(expected_status)
  end

  # Matcher for matching a session cookie
  #
  #   expect(last_response).to have_session_cookie
  #
  RSpec::Matchers.define(:have_session_cookie) do
    look_for = Webhookdb::Service::SESSION_COOKIE + "="

    match do |response|
      response["Set-Cookie"]&.include?(look_for)
    end

    failure_message do |string|
      "expected response Set-Cookie to include %p but got: %p" % [look_for, string]
    end
  end

  ### Create a new matcher that will expect the response to have a JSON body of
  ### the +expected_type+. If +expected_type+ is omitted, any JSON body will be sufficient
  ### for a match.
  module_function def have_json_body(expected_type=nil)
    return HaveJSONBodyMatcher.new(expected_type)
  end

  ### Parse the body of the last response and return it as a Ruby object.
  module_function def last_response_json_body(expected_type=nil)
    matcher = have_json_body(expected_type)
    expect(last_response).to(matcher)
    return matcher.parsed_response_body
  end

  #
  # Rack::Test overrides: Makes posts, puts, and patches JSON requests by default.
  #

  module WebhookdbTestMethods
    include Rack::Test::Methods

    def post(uri, params={}, env={}, &)
      env, params = make_json_request(env, params)
      super
    end

    def put(uri, params={}, env={}, &)
      env, params = make_json_request(env, params)
      super
    end

    def patch(uri, params={}, env={}, &)
      env, params = make_json_request(env, params)
      super
    end

    def make_json_request(env, params)
      env["CONTENT_TYPE"] ||= "application/json"

      params = Yajl::Encoder.encode(params) if env["CONTENT_TYPE"] == "application/json" && !params.is_a?(String)

      return env, params
    end
  end
end
