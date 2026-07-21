# frozen_string_literal: true

module ::DiscourseDiscordEvents
  module Discord
    module Errors
      class Error < StandardError
      end

      # Raised before any HTTP call when the plugin is not configured.
      class ConfigurationError < Error
      end

      # 401 — the bot token is missing or invalid.
      class AuthenticationError < Error
      end

      # 403 — the bot lacks access to the guild.
      class PermissionError < Error
      end

      # 404 — the guild (or resource) does not exist.
      class NotFoundError < Error
      end

      # 429 — rate limited, either preemptively or by Discord.
      class RateLimitedError < Error
        attr_reader :retry_after

        def initialize(message = nil, retry_after: nil)
          super(message)
          @retry_after = retry_after
        end
      end

      # 5xx — Discord is having a bad day.
      class ServerError < Error
      end

      # Any other unexpected HTTP status.
      class HTTPError < Error
        attr_reader :status

        def initialize(message = nil, status: nil)
          super(message)
          @status = status
        end
      end

      # Timeouts, DNS failures, connection resets.
      class NetworkError < Error
      end

      # The response body was not the JSON structure we expected.
      class MalformedResponseError < Error
      end
    end
  end
end
