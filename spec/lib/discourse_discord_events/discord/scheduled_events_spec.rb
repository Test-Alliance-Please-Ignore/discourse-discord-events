# frozen_string_literal: true

RSpec.describe DiscourseDiscordEvents::Discord::ScheduledEvents do
  subject(:endpoint) { described_class.new }

  let(:list_url) do
    "https://discord.com/api/v10/guilds/987654321098765432/scheduled-events?with_user_count=true"
  end

  before do
    enable_current_plugin
    SiteSetting.discord_events_bot_token = "test-token"
    SiteSetting.discord_events_guild_id = "987654321098765432"
  end

  describe "#list" do
    it "returns the array of scheduled event hashes" do
      events = [{ "id" => "1", "name" => "Movie Night" }]
      stub_request(:get, list_url).to_return(status: 200, body: events.to_json)

      expect(endpoint.list).to eq(events)
    end

    it "raises ConfigurationError without a guild id" do
      SiteSetting.discord_events_guild_id = ""

      expect { endpoint.list }.to raise_error(
        DiscourseDiscordEvents::Discord::Errors::ConfigurationError,
      )
    end

    it "raises MalformedResponseError when the response is not an array" do
      stub_request(:get, list_url).to_return(status: 200, body: { "id" => "1" }.to_json)

      expect { endpoint.list }.to raise_error(
        DiscourseDiscordEvents::Discord::Errors::MalformedResponseError,
      )
    end

    it "raises MalformedResponseError when array elements are not hashes" do
      stub_request(:get, list_url).to_return(status: 200, body: %w[bogus].to_json)

      expect { endpoint.list }.to raise_error(
        DiscourseDiscordEvents::Discord::Errors::MalformedResponseError,
      )
    end

    it "propagates client errors" do
      stub_request(:get, list_url).to_return(status: 401, body: "{}")

      expect { endpoint.list }.to raise_error(
        DiscourseDiscordEvents::Discord::Errors::AuthenticationError,
      )
    end
  end
end
