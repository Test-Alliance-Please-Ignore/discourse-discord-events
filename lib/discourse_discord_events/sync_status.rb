# frozen_string_literal: true

module ::DiscourseDiscordEvents
  # Persists synchronization state and history in the PluginStore so the
  # admin dashboard can report on it and jobs can avoid overlapping work.
  class SyncStatus
    STATUS_KEY = "sync_status"
    HISTORY_KEY = "sync_history"
    HISTORY_LIMIT = 20

    def self.current
      PluginStore.get(PLUGIN_NAME, STATUS_KEY) || {}
    end

    def self.history
      PluginStore.get(PLUGIN_NAME, HISTORY_KEY) || []
    end

    def self.record_start
      update(last_started_at: Time.zone.now.iso8601)
    end

    def self.record_success(result)
      entry = {
        "at" => Time.zone.now.iso8601,
        "success" => true,
        "duration_ms" => result.duration_ms,
        "created" => result.created,
        "updated" => result.updated,
        "deleted" => result.deleted,
        "completed" => result.completed,
        "skipped" => result.skipped,
        "pruned" => result.pruned,
      }

      update(
        last_completed_at: entry["at"],
        last_success_at: entry["at"],
        last_duration_ms: result.duration_ms,
        last_error: nil,
      )
      push_history(entry)
    end

    def self.record_failure(error, duration_ms)
      at = Time.zone.now.iso8601
      update(
        last_completed_at: at,
        last_duration_ms: duration_ms,
        last_error: {
          "message" => error.message,
          "error_class" => error.class.name,
          "at" => at,
        },
      )
      push_history(
        "at" => at,
        "success" => false,
        "duration_ms" => duration_ms,
        "error_class" => error.class.name,
        "message" => error.message,
      )
    end

    def self.reset!
      PluginStore.remove(PLUGIN_NAME, STATUS_KEY)
      PluginStore.remove(PLUGIN_NAME, HISTORY_KEY)
    end

    def self.update(attributes)
      PluginStore.set(PLUGIN_NAME, STATUS_KEY, current.merge(attributes.deep_stringify_keys))
    end

    def self.push_history(entry)
      PluginStore.set(PLUGIN_NAME, HISTORY_KEY, [entry, *history].first(HISTORY_LIMIT))
    end
    private_class_method :update, :push_history
  end
end
