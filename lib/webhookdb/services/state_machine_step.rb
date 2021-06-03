# frozen_string_literal: true

class Webhookdb::Services::StateMachineStep
  attr_accessor :needs_input,
                :prompt,
                :prompt_is_secret,
                :post_to_url,
                :complete,
                :output

  def mark_complete
    self.complete = true
    return self
  end
end
