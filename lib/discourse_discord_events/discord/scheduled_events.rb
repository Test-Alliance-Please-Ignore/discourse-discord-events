# frozen_string_literal: true

module ::DiscourseDiscordEvents
  module Discord
    # API endpoint wrapper for Discord Guild Scheduled Events.
    # https://discord.com/developers/docs/resources/guild-scheduled-event
    class ScheduledEvents
      def initialize(client: Client.new, guild_id: SiteSetting.discord_events_guild_id)
        @client = client
        @guild_id = guild_id
      end

      # Returns the raw array of scheduled event hashes for the guild,
      # including participant counts.
      def list
        ensure_configured!

        response = client.get("/guilds/#{guild_id}/scheduled-events", with_user_count: true)
        unless response.is_a?(Array) && response.all? { |event| event.is_a?(Hash) }
          raise Errors::MalformedResponseError, "Expected an array of scheduled events"
        end

        response
      end

      private

      attr_reader :client, :guild_id

      def ensure_configured!
        raise Errors::ConfigurationError, "Discord guild ID is not configured" if guild_id.blank?
      end
    end
  end
end
