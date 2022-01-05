# frozen_string_literal: true

require "webhookdb/aws"
require "webhookdb/slack"
require "webhookdb/spec_helpers"

module Webhookdb::SpecHelpers::Citest
  def self.run_tests(folder)
    out = StringIO.new
    err = StringIO.new
    RSpec::Core::Runner.run([folder + "/", "--format", "html"], err, out)

    notifier = Webhookdb::Slack.new_notifier(
      channel: "#webhookdb-notifications",
      username: "CI Tests",
      icon_emoji: ":female-detective:",
    )
    outstring = out.string
    result = Webhookdb::SpecHelpers::Citest.parse_rspec_html(outstring)
    unless result.ok?
      msg = "Errored or unparseable output running #{folder} tests:\nerror: #{err.string}\nout: #{outstring}"
      notifier.post text: msg
      return
    end

    url = self.put_results(folder, result.html)
    payload = self.result_to_payload(folder, result, url)
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

  def self.put_results(folder, html)
    return "https://unconfigured-url.s3" if Webhookdb::AWS.access_key_id.include?("default")
    now = Time.now
    bucket = "webhookdb-test-artifacts"
    key = "test-results/#{folder}/#{now.year}/#{now.month}/#{now.in_time_zone('UTC').iso8601}.html"
    Webhookdb::AWS.s3.put(
      bucket:,
      key:,
      body: html,
      content_type: "text/html",
    )
    url = Webhookdb::AWS.s3.presigned_get_url(bucket, key, expires_in: 1.week.to_i)
    return url
  end

  def self.result_to_payload(folder, result, html_url)
    color = "good"
    color = "warning" if result.pending.nonzero?
    color = "danger" if result.failures.nonzero?

    return {
      text: "Tests for #{folder}: #{result.examples} examples, #{result.failures} failures, #{result.pending} pending",
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
