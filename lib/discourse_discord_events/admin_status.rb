# frozen_string_literal: true

module ::DiscourseDiscordEvents
  # Aggregates everything the admin dashboard needs into one object.
  class AdminStatus
    include ActiveModel::Serialization

    def self.build
      new
    end

    def enabled
      SiteSetting.discord_events_enabled
    end

    def sync_enabled
      SiteSetting.discord_events_sync_enabled
    end

    def configured
      SiteSetting.discord_events_bot_token.present? &&
        SiteSetting.discord_events_guild_id.present?
    end

    def guild_id
      SiteSetting.discord_events_guild_id
    end

    def cached_event_count
      @cached_event_count ||= Event.count
    end

    def upcoming_event_count
      @upcoming_event_count ||= Event.upcoming.count
    end

    def past_event_count
      @past_event_count ||= Event.past.count
    end

    def sync_status
      @sync_status ||= SyncStatus.current
    end

    def last_started_at
      sync_status["last_started_at"]
    end

    def last_completed_at
      sync_status["last_completed_at"]
    end

    def last_success_at
      sync_status["last_success_at"]
    end

    def last_duration_ms
      sync_status["last_duration_ms"]
    end

    def last_error
      sync_status["last_error"]
    end

    def next_sync_at
      return unless enabled && sync_enabled
      return unless configured

      interval = SiteSetting.discord_events_sync_interval_minutes.minutes
      reference = last_started_at.present? ? Time.iso8601(last_started_at) : Time.zone.now
      [reference + interval, Time.zone.now].max.iso8601
    rescue ArgumentError
      nil
    end

    def rate_limited
      Discord::RateLimiter.new.blocked?
    end

    def history
      SyncStatus.history
    end
  end
end
