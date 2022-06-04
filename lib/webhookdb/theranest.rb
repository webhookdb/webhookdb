# frozen_string_literal: true

require "appydays/configurable"

module Webhookdb::Theranest
  include Appydays::Configurable

  configurable(:theranest) do
    setting :page_size, 50
  end
end
