# frozen_string_literal: true

module ::DiscourseDiscordEvents
  module Discord
    # Mirrors the guild's scheduled events into the local cache. Idempotent:
    # repeated runs converge on the same state and only write actual changes.
    #
    # Discord's list endpoint only returns scheduled and active events, so
    # events that disappear from the API are either finished (kept and marked
    # completed) or were deleted before they started (removed from the cache).
    class Synchronizer
      CDN_BASE = "https://cdn.discordapp.com"

      class Result
        attr_accessor :created, :updated, :deleted, :completed, :skipped, :pruned, :duration_ms

        def initialize
          @created = @updated = @deleted = @completed = @skipped = @pruned = @duration_ms = 0
        end
      end

      def self.sync!
        new.sync!
      end

      def initialize(scheduled_events: ScheduledEvents.new)
        @scheduled_events = scheduled_events
        @result = Result.new
      end

      def sync!
        started_at = now_monotonic
        SyncStatus.record_start

        payloads = scheduled_events.list

        Event.transaction do
          upsert_events(payloads)
          resolve_missing_events(payloads)
          drop_foreign_guild_events
        end
        result.pruned = Event.prune_to_limit(SiteSetting.discord_events_max_cached_events)

        result.duration_ms = elapsed_ms(started_at)
        SyncStatus.record_success(result)
        log_summary
        result
      rescue => e
        SyncStatus.record_failure(e, elapsed_ms(started_at))
        Rails.logger.error("[discourse-discord-events] Sync failed: #{e.class}: #{e.message}")
        raise
      end

      private

      attr_reader :scheduled_events, :result

      def guild_id
        SiteSetting.discord_events_guild_id
      end

      def upsert_events(payloads)
        existing = Event.where(guild_id: guild_id).index_by(&:discord_event_id)
        synced_at = Time.zone.now

        payloads.each do |payload|
          attributes = map_attributes(payload)
          if attributes.nil?
            result.skipped += 1
            next
          end

          event = existing[payload["id"]] || Event.new
          persist(event, attributes, synced_at)
        end
      end

      def persist(event, attributes, synced_at)
        newly_created = event.new_record?
        event.assign_attributes(attributes)
        return if !newly_created && !event.changed?

        event.synced_at = synced_at
        event.save!
        newly_created ? result.created += 1 : result.updated += 1
      rescue ActiveRecord::RecordInvalid => e
        result.skipped += 1
        Rails.logger.warn(
          "[discourse-discord-events] Skipped invalid event #{attributes[:discord_event_id]}: #{e.message}",
        )
      end

      # Events cached locally but absent from the API response.
      def resolve_missing_events(payloads)
        seen_ids = payloads.map { |payload| payload["id"] }.compact
        missing = Event.where(guild_id: guild_id).where.not(discord_event_id: seen_ids)

        started = missing.where(status: :active).or(
          missing.where(status: :scheduled).where("scheduled_start_time < ?", Time.zone.now),
        )
        result.completed +=
          started.update_all(status: Event.statuses[:completed], updated_at: Time.zone.now)

        unstarted =
          missing.where(status: :scheduled).where("scheduled_start_time >= ?", Time.zone.now)
        result.deleted += unstarted.delete_all
      end

      # When the configured guild changes, cached events of the old guild
      # would otherwise linger forever.
      def drop_foreign_guild_events
        result.deleted += Event.where.not(guild_id: guild_id).delete_all
      end

      def map_attributes(payload)
        status = payload["status"]
        entity_type = payload["entity_type"]
        start_time = parse_time(payload["scheduled_start_time"])

        if payload["id"].blank? || payload["name"].blank? || start_time.nil? ||
             !Event.statuses.value?(status) || !Event.entity_types.value?(entity_type)
          Rails.logger.warn(
            "[discourse-discord-events] Skipped malformed event payload #{payload["id"].inspect}",
          )
          return nil
        end

        location = payload.dig("entity_metadata", "location").presence

        {
          discord_event_id: payload["id"],
          guild_id: payload["guild_id"].presence || guild_id,
          name: payload["name"],
          description: payload["description"].presence&.truncate(5000),
          image_url: image_url(payload),
          status: status,
          entity_type: entity_type,
          location: location&.truncate(255),
          external_url: external_url(location),
          creator_name: creator_name(payload),
          participant_count: payload["user_count"],
          privacy_level: normalize_privacy_level(payload["privacy_level"]),
          scheduled_start_time: start_time,
          scheduled_end_time: parse_time(payload["scheduled_end_time"]),
          raw_json: payload,
        }
      end

      def parse_time(value)
        return if value.blank?
        Time.iso8601(value)
      rescue ArgumentError
        nil
      end

      def image_url(payload)
        image_hash = payload["image"]
        return if image_hash.blank? || !image_hash.match?(/\A[a-zA-Z0-9_]+\z/)

        "#{CDN_BASE}/guild-events/#{payload["id"]}/#{image_hash}.png?size=1024"
      end

      def external_url(location)
        return if location.blank?

        uri = URI.parse(location)
        location if uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
      rescue URI::InvalidURIError
        nil
      end

      def creator_name(payload)
        creator = payload["creator"]
        return unless creator.is_a?(Hash)

        (creator["global_name"].presence || creator["username"].presence)&.truncate(255)
      end

      def normalize_privacy_level(value)
        Event.privacy_levels.value?(value) ? value : Event.privacy_levels[:guild_only]
      end

      def log_summary
        Rails.logger.info(
          "[discourse-discord-events] Sync finished in #{result.duration_ms}ms: " \
            "#{result.created} created, #{result.updated} updated, #{result.deleted} deleted, " \
            "#{result.completed} completed, #{result.skipped} skipped, #{result.pruned} pruned",
        )
      end

      def now_monotonic
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def elapsed_ms(started_at)
        ((now_monotonic - started_at) * 1000).round
      end
    end
  end
end
