# frozen_string_literal: true

module ::DiscourseDiscordEvents
  class AdminDiscordEventsController < ::Admin::AdminController
    requires_plugin PLUGIN_NAME

    def status
      render_serialized(AdminStatus.build, AdminStatusSerializer, root: false)
    end

    def test_connection
      events = Discord::ScheduledEvents.new.list
      render json: success_json.merge(event_count: events.size)
    rescue Discord::Errors::Error => e
      render json: failed_json.merge(error: friendly_error_message(e)), status: :unprocessable_content
    end

    def sync
      Jobs.enqueue(Jobs::DiscourseDiscordEvents::SyncScheduledEvents)
      render json: success_json
    end

    def clear_cache
      deleted = Event.delete_all
      SyncStatus.reset!
      render json: success_json.merge(deleted: deleted)
    end

    private

    ERROR_KEYS = {
      Discord::Errors::ConfigurationError => "configuration",
      Discord::Errors::AuthenticationError => "authentication",
      Discord::Errors::PermissionError => "permission",
      Discord::Errors::NotFoundError => "not_found",
      Discord::Errors::RateLimitedError => "rate_limited",
      Discord::Errors::ServerError => "server",
      Discord::Errors::NetworkError => "network",
      Discord::Errors::MalformedResponseError => "malformed",
    }.freeze

    def friendly_error_message(error)
      key = ERROR_KEYS.fetch(error.class, "http")
      I18n.t("discord_events.errors.#{key}")
    end
  end
end
