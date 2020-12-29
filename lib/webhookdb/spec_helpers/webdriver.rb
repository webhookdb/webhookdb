# frozen_string_literal: true

require "appydays/configurable"
require "forwardable"
require "rspec"
require "rspec/eventually"
require "watir"
require "webdrivers"
require "yaml"

require "webhookdb"

raise "webdriver tests not enabled, this file should not have been evaluated" unless
  Webhookdb::WEBDRIVER_TESTS_ENABLED

module Webhookdb::WebdriverSpecHelpers
  include Appydays::Configurable
  include Appydays::Loggable
  extend Webhookdb::MethodUtilities

  DRIVERS = {
    chrome: Webdrivers::Chromedriver,
  }.freeze

  configurable(:webdriver_tests) do
    setting :browser, "chrome"
    setting :headless, false
    setting :browser_options, {}, convert: ->(s) { Yajl::Parser.parse(s) }
    setting :window_width, nil
    setting :window_height, nil
  end

  def self.check_browser
    b = self.browser.to_sym
    (driver = DRIVERS[b]) or raise "Invalid configured browser '#{b}', must be one of #{DRIVERS.keys}"
    driver.download if driver.current_version.nil?
  end

  def self.new_browser
    opts = self.browser_options.dup
    (opts[:headless] = true) if self.headless
    b = Watir::Browser.new(self.browser.to_sym, opts)

    if (ww = self.window_width) || (wh = self.window_height)
      size = b.window.size
      ww ||= size[0]
      wh ||= size[1]
      b.window.resize_to(ww, wh)
    end

    # On desktops, the browser opens in a background window,
    # which can 1) break JS events but also
    # 2) make it really hard to know what's going on/see your tests running.
    is_osx = RUBY_PLATFORM.include?("darwin")
    `osascript -e 'tell app "#{self.browser}" to activate'` if is_osx && !self.headless

    return b
  end

  def self.included(config)
    Webhookdb::WebdriverSpecHelpers.check_browser

    Watir.default_timeout = 5
    config.include InstanceMethods

    config.around(:example) do |example|
      raise "Other tests should not be run during webdriver tests (or this test needs an :webdriver flag" unless
        example.metadata[:webdriver]

      WebMock.allow_net_connect!

      @deletables = []
      @browser = Webhookdb::WebdriverSpecHelpers.new_browser
      begin
        example.run
      ensure
        @browser.close
        @deletables.each(&:soft_delete)
      end
    end
    super
  end

  module InstanceMethods
    extend Forwardable

    def wtf!
      puts "Pausing specs. Ctrl+D to resume."
      $stdin.read
      puts "Specs resuming in 5 seconds. Switch back to your browser!"
      sleep(5)
    end

    def_delegators :browser, :send_keys, :text, :title, :url

    def log
      Webhookdb::WebdriverSpecHelpers.log
    end

    def delete_after
      m = yield()
      @deletables << m
      return m
    end

    def browser
      return @browser
    end

    def goto(tail)
      root = Webhookdb.app_url.sub(%r{/$}, "")
      self.logger.info "goto: #{root + tail}"
      puts "goto: #{root + tail}"
      self.browser.goto root + tail
    end

    # Ruby equivalent of javascripts encodeURIComponent.
    # http://stackoverflow.com/questions/2834034/how-do-i-raw-url-encode-decode-in-javascript-and-ruby-to-get-the-same-values-in/2834053#2834053
    def uri_escape(string)
      return CGI.escape(string)
    end

    def preauth(customer, nxt)
      params = [
        "email=#{self.uri_escape(customer.email)}",
        "next=#{self.uri_escape(nxt)}",
      ]
      self.goto "/preauth?#{params.join('&')}"
      expect { url }.to eventually(end_with nxt)
    end

    def checkbox(opts={})
      self.browser.checkbox(self.coerce_selector_options("input", opts))
    end

    def radio(opts={})
      self.browser.radio(self.coerce_selector_options("input", opts))
    end

    def label(opts={})
      self.browser.label(self.coerce_selector_options("label", opts))
    end

    def text_field(opts={})
      self.browser.text_field(self.coerce_selector_options("input", opts))
    end

    def textarea(opts={})
      self.browser.textarea(self.coerce_selector_options("textarea", opts))
    end

    def select(opts={})
      self.browser.select_list(self.coerce_selector_options("select", opts))
    end

    def link(opts={})
      self.browser.link(self.coerce_selector_options("a", opts))
    end

    def button(opts={})
      self.browser.button(self.coerce_selector_options("button", opts))
    end

    def div(opts={})
      self.browser.div(self.coerce_selector_options("div", opts))
    end

    def coerce_selector_options(tag, opts)
      opts = {webdriverid: opts} if opts.is_a?(String)
      opts[:visible] = true unless opts.key?(:visible)
      if (contains = opts.delete(:contains))
        opts[:xpath] = "//#{tag}[contains(@data-webdriverid,'#{contains}')]"
      elsif (webdriverid = opts.delete(:webdriverid))
        opts[:xpath] = "//#{tag}[@data-webdriverid='#{webdriverid}']"
      end
      return opts
    end

    def submission_button
      self.browser.button(type: "submit")
    end

    def submit_form
      self.submission_button.click
    end

    def submit_modal
      self.browser.button(self.coerce_selector_options("button", "modal-submit")).click
    end

    def cancel_modal
      self.browser.button(self.coerce_selector_options("button", "modal-cancel")).click
    end

    def wait_for(element)
      expect { element.present? }.to eventually(be_present)
      return element
    end

    def swallow_unclickable
      yield()
    rescue Selenium::WebDriver::Error::UnknownError => e
      raise e unless /is not clickable/.match?(e.to_s)
    end

    def wait_for_visible_click(element)
      Array.new(20) do |i|
        element.click
        break
      rescue Selenium::WebDriver::Error::UnknownError => e
        raise e if i == 19
        raise e unless /is not clickable/.match?(e.to_s)
        sleep(0.1)
      end
    end

    def scroll_to(element)
      self.browser.execute_script("arguments[0].scrollIntoView();", element)
      return element
    end

    def customer_fixture
      return Webhookdb::Fixtures.customer
    end
  end
end
