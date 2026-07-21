# frozen_string_literal: true

RSpec.describe DiscourseDiscordEvents::Discord::Client do
  subject(:client) { described_class.new(rate_limiter: rate_limiter) }

  let(:rate_limiter) { DiscourseDiscordEvents::Discord::RateLimiter.new }
  let(:api_url) { "https://discord.com/api/v10/gateway" }

  before do
    enable_current_plugin
    SiteSetting.discord_events_bot_token = "test-token"
  end

  after { rate_limiter.reset! }

  describe "#get" do
    it "sends an authenticated request and parses the JSON response" do
      stub =
        stub_request(:get, api_url).with(
          headers: {
            "Authorization" => "Bot test-token",
          },
        ).to_return(status: 200, body: { "url" => "wss://gateway.discord.gg" }.to_json)

      expect(client.get("/gateway")).to eq("url" => "wss://gateway.discord.gg")
      expect(stub).to have_been_requested
    end

    it "appends query parameters" do
      stub =
        stub_request(:get, "#{api_url}?with_user_count=true").to_return(status: 200, body: "{}")

      client.get("/gateway", with_user_count: true)

      expect(stub).to have_been_requested
    end

    it "raises ConfigurationError without a bot token" do
      SiteSetting.discord_events_bot_token = ""

      expect { client.get("/gateway") }.to raise_error(
        DiscourseDiscordEvents::Discord::Errors::ConfigurationError,
      )
    end

    it "raises AuthenticationError on 401" do
      stub_request(:get, api_url).to_return(status: 401, body: "{}")

      expect { client.get("/gateway") }.to raise_error(
        DiscourseDiscordEvents::Discord::Errors::AuthenticationError,
      )
    end

    it "raises PermissionError on 403" do
      stub_request(:get, api_url).to_return(status: 403, body: "{}")

      expect { client.get("/gateway") }.to raise_error(
        DiscourseDiscordEvents::Discord::Errors::PermissionError,
      )
    end

    it "raises NotFoundError on 404" do
      stub_request(:get, api_url).to_return(status: 404, body: "{}")

      expect { client.get("/gateway") }.to raise_error(
        DiscourseDiscordEvents::Discord::Errors::NotFoundError,
      )
    end

    it "raises ServerError on 5xx" do
      stub_request(:get, api_url).to_return(status: 502, body: "Bad Gateway")

      expect { client.get("/gateway") }.to raise_error(
        DiscourseDiscordEvents::Discord::Errors::ServerError,
      )
    end

    it "raises HTTPError with the status on other codes" do
      stub_request(:get, api_url).to_return(status: 418, body: "")

      expect { client.get("/gateway") }.to raise_error(
        DiscourseDiscordEvents::Discord::Errors::HTTPError,
      ) { |error| expect(error.status).to eq(418) }
    end

    it "raises MalformedResponseError on invalid JSON" do
      stub_request(:get, api_url).to_return(status: 200, body: "<html>not json</html>")

      expect { client.get("/gateway") }.to raise_error(
        DiscourseDiscordEvents::Discord::Errors::MalformedResponseError,
      )
    end

    it "raises NetworkError on timeouts" do
      stub_request(:get, api_url).to_timeout

      expect { client.get("/gateway") }.to raise_error(
        DiscourseDiscordEvents::Discord::Errors::NetworkError,
      )
    end

    context "when rate limited" do
      it "records the 429 retry_after and raises RateLimitedError" do
        stub_request(:get, api_url).to_return(
          status: 429,
          body: { "message" => "You are being rate limited.", "retry_after" => 7.5 }.to_json,
        )

        expect { client.get("/gateway") }.to raise_error(
          DiscourseDiscordEvents::Discord::Errors::RateLimitedError,
        ) { |error| expect(error.retry_after).to eq(7.5) }

        expect(rate_limiter.blocked?).to eq(true)
      end

      it "refuses to call Discord while a rate limit is in effect" do
        rate_limiter.record_rate_limit!(60)
        stub = stub_request(:get, api_url)

        expect { client.get("/gateway") }.to raise_error(
          DiscourseDiscordEvents::Discord::Errors::RateLimitedError,
        )
        expect(stub).not_to have_been_requested
      end

      it "preemptively blocks when the response bucket is exhausted" do
        stub_request(:get, api_url).to_return(
          status: 200,
          body: "{}",
          headers: {
            "X-RateLimit-Remaining" => "0",
            "X-RateLimit-Reset-After" => "20",
          },
        )

        client.get("/gateway")

        expect(rate_limiter.blocked?).to eq(true)
      end
    end
  end
end
