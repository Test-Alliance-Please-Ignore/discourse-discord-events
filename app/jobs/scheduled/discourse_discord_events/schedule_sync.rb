# frozen_string_literal: true

module Jobs
  module DiscourseDiscordEvents
    # Runs frequently but only enqueues an actual sync when the configured
    # interval has elapsed, so admins can tune the cadence via site setting.
    class ScheduleSync < ::Jobs::Scheduled
      every 5.minutes

      REDIS_KEY = "discourse-discord-events:last-scheduled-sync"

      def execute(_args = nil)
        return unless SiteSetting.discord_events_enabled
        return unless SiteSetting.discord_events_sync_enabled
        return unless due?

        Jobs.enqueue(Jobs::DiscourseDiscordEvents::SyncScheduledEvents)
      end

      private

      def due?
        window = SiteSetting.discord_events_sync_interval_minutes.minutes - 10.seconds
        Discourse.redis.set(REDIS_KEY, 1, ex: window.to_i, nx: true)
      end
    end
  end
end
