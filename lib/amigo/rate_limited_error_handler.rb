# frozen_string_literal: true

require "digest"

module Amigo
  # This is a placeholder until it's migrated to Amigo proper
end

# Wrap another Sidekiq error handler so invoking it is rate limited.
#
# Useful when wrapping a usage-based error reporter like Sentry,
# which can be hammered in the case of an issue like connectivity
# that causes all jobs and retries to fail.
# It is suggested that all errors are still reported to something
# like application logs, since entirely silencing errors
# can make debugging problems tricky.
#
# Usage:
#
#   Sidekiq.configure_server do |config|
#     config.error_handlers << Amigo::RateLimitedErrorHandler.new(
#       Sentry::Sidekiq::ErrorHandler.new,
#       sample_rate: ENV.fetch('ASYNC_ERROR_RATE_LIMITER_SAMPLE_RATE', '0.5').to_f,
#       ttl: ENV.fetch('ASYNC_ERROR_RATE_LIMITER_TTL', '120').to_f,
#     )
#   end
#
# See notes about +sample_rate+ and +ttl+,
# and +fingerprint+ for how exceptions are fingerprinted for uniqueness.
#
# Rate limiting is done in-memory so is unique across the entire process-
# threads/workers share rate limiting, but multiple processes do not.
# So if 2 processes have 10 threads each,
# the error handler would be invoked twice if they all error
# for the same reason.
#
# Thread-based limiting (20 errors in the case above)
# or cross-process limiting (1 error in the case above)
# can be added in the future.
class Amigo::RateLimitedErrorHandler
  # The error handler that will be called to report the error.
  attr_reader :wrapped

  # After the first error with a fingerprint is seen,
  # how many future errors with the same fingerprint should we sample,
  # until the fingerprint expires +ttl+ after the first error?
  # Use 1 to called the wrapped handler on all errors with the same fingerprint,
  # and 0 to never call the wrapped handler on those errors until ttl has elapsed.
  attr_reader :sample_rate

  # How long does the fingerprint live for an error?
  # For example, with a sample rate of 0 and a ttl of 2 minutes,
  # the rate will be at most one of the same error every 2 minutes;
  # the error is always sent when the key is set; then no events are sent until the key expires.
  #
  # Note that, unlike Redis TTL, the ttl is set only when the error is first seen
  # (and then after it's seen once the fingerprint expires);
  # this means that, if an error is seen once a minute, with a TTL of 2 minutes,
  # even with a sample rate of 0, an error is recorded every 2 minutes,
  # rather than just once and never again.
  attr_reader :ttl

  def initialize(wrapped, sample_rate: 0.1, ttl: 120)
    @mutex = Mutex.new
    @wrapped = wrapped
    @sample_rate = sample_rate
    @inverse_sample_rate = 1 - @sample_rate
    @ttl = ttl
    # Key is fingerprint, value is when to expire
    @store = {}
    # Add some fast-paths to handle 0 and 1 sample rates.
    @call = if sample_rate == 1
              ->(*a) { @wrapped.call(*a) }
    elsif sample_rate.zero?
      self.method(:call_zero)
    else
      self.method(:call_sampled)
    end
  end

  def call(ex, context)
    @call[ex, context]
  end

  private def call_zero(ex, context)
    call_impl(ex, context) { false }
  end

  private def call_sampled(ex, context)
    call_impl(ex, context) { rand <= @sample_rate }
  end

  private def call_impl(ex, context)
    now = Time.now
    invoke = @mutex.synchronize do
      @store.delete_if { |_sig, t| t < now }
      fingerprint = self.fingerprint(ex)
      if @store.key?(fingerprint)
        yield
      else
        @store[fingerprint] = now + @ttl
        true
      end
    end
    @wrapped.call(ex, context) if invoke
  end

  # Fingerprint an exception.
  # - No two exceptions with the same class can be the same.
  # - If an exception has no backtrace (it was manually constructed),
  #   the identity of the exception instance (object_id) is the fingerprint.
  # - If an exception has a backtrace,
  #   the md5 of the backtrace is the fingerprint.
  def fingerprint(ex)
    md5 = Digest::MD5.new               # =>#<Digest::MD5>
    md5.update ex.class.to_s
    if ex.backtrace.nil?
      md5.update ex.object_id.to_s
    else
      ex.backtrace.each { |line| md5.update(line) }
    end
    md5.update(self.fingerprint(ex.cause)) if ex.cause
    return md5.hexdigest
  end
end
