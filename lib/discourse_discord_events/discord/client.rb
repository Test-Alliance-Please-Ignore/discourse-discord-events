# frozen_string_literal: true

module ::DiscourseDiscordEvents
  module Discord
    # Thin, authenticated JSON client for the Discord REST API. All HTTP
    # communication of the plugin goes through this class.
    class Client
      API_HOST = "discord.com"
      API_BASE_PATH = "/api/v10"
      TIMEOUT_SECONDS = 15

      def initialize(bot_token: SiteSetting.discord_events_bot_token, rate_limiter: RateLimiter.new)
        @bot_token = bot_token
        @rate_limiter = rate_limiter
      end

      def get(path, params = {})
        ensure_configured!
        ensure_not_rate_limited!

        response = perform_get(path, params)
        rate_limiter.track_response_headers(response)
        handle_response(response)
      rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED,
             Errno::ECONNRESET, Errno::EHOSTUNREACH, OpenSSL::SSL::SSLError, EOFError => e
        raise Errors::NetworkError, "Discord API unreachable: #{e.class}"
      end

      private

      attr_reader :bot_token, :rate_limiter

      def ensure_configured!
        raise Errors::ConfigurationError, "Discord bot token is not configured" if bot_token.blank?
      end

      def ensure_not_rate_limited!
        return unless rate_limiter.blocked?

        wait = rate_limiter.wait_time
        raise Errors::RateLimitedError.new(
                "Discord rate limit in effect for another #{wait.ceil}s",
                retry_after: wait,
              )
      end

      def perform_get(path, params)
        uri = URI("https://#{API_HOST}#{API_BASE_PATH}#{path}")
        uri.query = URI.encode_www_form(params) if params.present?

        http = FinalDestination::HTTP.new(API_HOST, 443)
        http.use_ssl = true
        http.open_timeout = TIMEOUT_SECONDS
        http.read_timeout = TIMEOUT_SECONDS

        request = Net::HTTP::Get.new(uri)
        request["Authorization"] = "Bot #{bot_token}"
        request["User-Agent"] = "Discourse-Discord-Events (#{Discourse.base_url}, 0.1.0)"

        http.request(request)
      end

      def handle_response(response)
        case response.code.to_i
        when 200
          parse_json(response.body)
        when 401
          raise Errors::AuthenticationError, "Discord rejected the bot token"
        when 403
          raise Errors::PermissionError, "The bot is not allowed to access this resource"
        when 404
          raise Errors::NotFoundError, "Discord resource not found"
        when 429
          handle_rate_limit(response)
        when 500..599
          raise Errors::ServerError, "Discord returned HTTP #{response.code}"
        else
          raise Errors::HTTPError.new(
                  "Unexpected Discord response HTTP #{response.code}",
                  status: response.code.to_i,
                )
        end
      end

      def handle_rate_limit(response)
        retry_after = rate_limit_retry_after(response)
        rate_limiter.record_rate_limit!(retry_after)
        raise Errors::RateLimitedError.new(
                "Discord rate limited the request (retry after #{retry_after}s)",
                retry_after: retry_after,
              )
      end

      def rate_limit_retry_after(response)
        parsed =
          begin
            JSON.parse(response.body)
          rescue JSON::ParserError, TypeError
            nil
          end

        retry_after = parsed.is_a?(Hash) ? parsed["retry_after"] : nil
        (retry_after || response["retry-after"] || 5).to_f
      end

      def parse_json(body)
        JSON.parse(body)
      rescue JSON::ParserError
        raise Errors::MalformedResponseError, "Discord returned a non-JSON response"
      end
    end
  end
end
