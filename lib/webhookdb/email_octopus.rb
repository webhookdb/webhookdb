# frozen_string_literal: true

require "appydays/configurable"

module Webhookdb::EmailOctopus
  include Appydays::Configurable

  configurable(:email_octopus) do
    setting :page_size, 100
  end
end
