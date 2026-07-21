# frozen_string_literal: true

module ::DiscourseDiscordEvents
  class AdminStatusSerializer < ApplicationSerializer
    attributes :enabled,
               :sync_enabled,
               :configured,
               :guild_id,
               :cached_event_count,
               :upcoming_event_count,
               :past_event_count,
               :last_started_at,
               :last_completed_at,
               :last_success_at,
               :last_duration_ms,
               :last_error,
               :next_sync_at,
               :rate_limited,
               :history
  end
end
