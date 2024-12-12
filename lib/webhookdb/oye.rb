# frozen_string_literal: true

class Webhookdb::Oye
  include Appydays::Configurable

  configurable(:oye) do
    setting :http_timeout, 30
  end
end
