# frozen_string_literal: true

module Jobs
  module DiscourseDiscordEvents
    # Performs one synchronization run. Transient Discord failures are retried
    # with backoff; configuration and permission problems are not, since they
    # need an admin to intervene and are surfaced on the admin dashboard.
    class SyncScheduledEvents < ::Jobs::Base
      MAX_ATTEMPTS = 5
      BASE_RETRY_DELAY = 30.seconds
      MAX_RETRY_DELAY = 15.minutes
      MUTEX_KEY = "discourse-discord-events-sync"

      TRANSIENT_ERRORS = [
        ::DiscourseDiscordEvents::Discord::Errors::NetworkError,
        ::DiscourseDiscordEvents::Discord::Errors::ServerError,
      ].freeze

      def execute(args = {})
        return unless SiteSetting.discord_events_enabled

        attempt = args[:attempt].to_i.clamp(1, MAX_ATTEMPTS)

        DistributedMutex.synchronize(MUTEX_KEY, validity: 5.minutes) do
          ::DiscourseDiscordEvents::Discord::Synchronizer.sync!
        end
      rescue ::DiscourseDiscordEvents::Discord::Errors::RateLimitedError => e
        retry_later(attempt, delay: [e.retry_after.to_f, 5].max.seconds)
      rescue *TRANSIENT_ERRORS
        retry_later(attempt, delay: backoff(attempt))
      rescue ::DiscourseDiscordEvents::Discord::Errors::Error
        # Permanent until an admin fixes the configuration; already recorded
        # in SyncStatus by the synchronizer.
        nil
      end

      private

      def retry_later(attempt, delay:)
        if attempt >= MAX_ATTEMPTS
          Rails.logger.error(
            "[discourse-discord-events] Giving up after #{attempt} sync attempts",
          )
          return
        end

        Jobs.enqueue_in(
          delay,
          Jobs::DiscourseDiscordEvents::SyncScheduledEvents,
          attempt: attempt + 1,
        )
      end

      def backoff(attempt)
        [BASE_RETRY_DELAY * (2**(attempt - 1)), MAX_RETRY_DELAY].min
      end
    end
  end
end
