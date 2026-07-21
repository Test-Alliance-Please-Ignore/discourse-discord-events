# frozen_string_literal: true

module ::DiscourseDiscordEvents
  module Discord
    # Tracks Discord rate limit state in Redis so all processes (web, sidekiq)
    # back off together. Discord communicates limits via response headers and
    # 429 bodies; we store the earliest time a new request is allowed.
    class RateLimiter
      REDIS_KEY = "discourse-discord-events:blocked-until"

      def blocked?
        wait_time.positive?
      end

      def wait_time
        blocked_until = Discourse.redis.get(REDIS_KEY)
        return 0 unless blocked_until

        [blocked_until.to_f - Time.now.to_f, 0].max
      end

      def record_rate_limit!(retry_after_seconds)
        seconds = [retry_after_seconds.to_f, 1.0].max
        Discourse.redis.setex(REDIS_KEY, seconds.ceil, (Time.now.to_f + seconds).to_s)
      end

      # Called with every successful response so we preemptively pause when
      # the current rate limit bucket is exhausted.
      def track_response_headers(headers)
        remaining = headers["x-ratelimit-remaining"]
        reset_after = headers["x-ratelimit-reset-after"]
        return if remaining.nil? || reset_after.nil?

        record_rate_limit!(reset_after) if remaining.to_i <= 0
      end

      def reset!
        Discourse.redis.del(REDIS_KEY)
      end
    end
  end
end
