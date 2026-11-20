# frozen_string_literal: true

require "webhookdb/slack"
require "webhookdb/spec_helpers"

module Webhookdb::SpecHelpers::Citest
  INTEGRATION_TESTS_DIR = Pathname(__FILE__).dirname.parent.parent.parent + "integration"

  # Run RSpec against the given folders, create a DatabaseDocument for the html results,
  # and POST to Slack about it.
  def self.run_tests(folders)
    out = StringIO.new
    err = StringIO.new
    folders = [folders] unless folders.respond_to?(:to_ary)
    args = folders.map { |f| "#{f}/" }
    args << "--format"
    args << "html"
    RSpec::Core::Runner.run(args, err, out)

    notifier = Webhookdb::Slack.new_notifier(
      force_channel: "#webhookdb-notifications",
      username: "CI Tests",
      icon_emoji: ":female-detective:",
    )
    outstring = out.string
    result = Webhookdb::SpecHelpers::Citest.parse_rspec_html(outstring)
    unless result.ok?
      msg = "Errored or unparseable output running #{folders.join(', ')} tests:" \
            "\nerror: #{err.string}\nout: #{outstring}"
      notifier.post text: msg
      return
    end

    url = self.put_results(result.html)
    payload = self.result_to_payload(result, url)
    notifier.post(payload)
  end

  def self.parse_rspec_html(output)
    result = RSpecResult.new
    html = []
    output.lines.each do |line|
      next if line.strip.start_with?("Run options") || line.strip.starts_with?("All examples were")
      html << line
      captures = line.match(/innerHTML = "(\d+ examples?), (\d+ failures?)(, )?(\d+ pending)?/)&.captures
      next unless captures
      result.examples = captures[0].to_i
      result.failures = captures[1].to_i
      result.pending = captures[3].to_i
    end
    result.html = html.join
    return result
  end

  def self.put_results(html, key: "integration")
    now = Time.now
    key = "test-results/#{key}/#{now.year}/#{now.month}/#{now.in_time_zone('UTC').iso8601}.html"
    doc = Webhookdb::DatabaseDocument.create(
      key:,
      content: html,
      content_type: "text/html",
    )
    url = doc.presigned_admin_view_url(expire_at: 1.week.from_now)
    return url
  end

  def self.result_to_payload(result, html_url, prefix: "Integration Tests")
    color = "good"
    color = "warning" if result.pending.nonzero?
    color = "danger" if result.failures.nonzero?

    return {
      text: "#{prefix}: #{result.examples} examples, #{result.failures} failures, #{result.pending} pending",
      attachments: [
        {
          color:,
          fallback: "View results at #{html_url}",
          actions: [
            {
              type: "button",
              text: "View Results 🔎",
              url: html_url,
            },
          ],
        },
      ],
    }
  end

  class RSpecResult
    attr_accessor :html, :examples, :failures, :pending

    def ok?
      return !self.examples.nil?
    end
  end
end
