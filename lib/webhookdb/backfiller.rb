# frozen_string_literal: true

# Implementation of a generic backfill pattern.
class Webhookdb::Backfiller
  # Called for each item.
  def handle_item(item)
    raise NotImplementedError
  end

  def fetch_backfill_page(pagination_token, last_backfilled:)
    raise NotImplementedError
  end

  # Use nil last_backfilled for a full sync, pass it for an incremental.
  # Should be service integration last_backfilled_at, the timestamp of
  # the latest resource, etc.
  def backfill(last_backfilled)
    pagination_token = nil
    loop do
      page, next_pagination_token = self._fetch_backfill_page_with_retry(
        pagination_token, last_backfilled:,
      )
      pagination_token = next_pagination_token
      page.each do |item|
        self.handle_item(item)
      end
      Amigo::DurableJob.heartbeat
      break if pagination_token.blank?
    end
  end

  def max_backfill_retry_attempts
    return 3
  end

  def wait_for_retry_attempt(attempt:)
    Webhookdb::Backfiller.do_retry_wait(attempt)
  end

  # Make this easy to mock
  def self.do_retry_wait(seconds)
    sleep(seconds)
  end

  def _fetch_backfill_page_with_retry(pagination_token, last_backfilled: nil, attempt: 1)
    return self.fetch_backfill_page(pagination_token, last_backfilled:)
  rescue RuntimeError => e
    raise e if attempt >= self.max_backfill_retry_attempts
    self.wait_for_retry_attempt(attempt:)
    return self._fetch_backfill_page_with_retry(pagination_token, last_backfilled:, attempt: attempt + 1)
  end
end
