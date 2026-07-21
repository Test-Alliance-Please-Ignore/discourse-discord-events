# frozen_string_literal: true

RSpec.describe DiscourseDiscordEvents::AdminDiscordEventsController do
  fab!(:admin)
  fab!(:user)

  let(:guild_id) { "987654321098765432" }
  let(:list_url) do
    "https://discord.com/api/v10/guilds/#{guild_id}/scheduled-events?with_user_count=true"
  end

  before do
    enable_current_plugin
    SiteSetting.discord_events_bot_token = "test-token"
    SiteSetting.discord_events_guild_id = guild_id
  end

  describe "#status" do
    it "requires an admin" do
      sign_in(user)

      get "/admin/plugins/discourse-discord-events/status.json"

      expect(response.status).to eq(404)
    end

    it "returns the aggregated status" do
      sign_in(admin)
      Fabricate(:discord_event, guild_id: guild_id)
      Fabricate(:discord_event, guild_id: guild_id, status: :completed, scheduled_start_time: 2.days.ago)

      get "/admin/plugins/discourse-discord-events/status.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["enabled"]).to eq(true)
      expect(response.parsed_body["configured"]).to eq(true)
      expect(response.parsed_body["guild_id"]).to eq(guild_id)
      expect(response.parsed_body["cached_event_count"]).to eq(2)
      expect(response.parsed_body["upcoming_event_count"]).to eq(1)
      expect(response.parsed_body["past_event_count"]).to eq(1)
      expect(response.parsed_body).to have_key("history")
    end

    it "never exposes the bot token" do
      sign_in(admin)

      get "/admin/plugins/discourse-discord-events/status.json"

      expect(response.body).not_to include("test-token")
    end

    it "is not accessible when the plugin is disabled" do
      SiteSetting.discord_events_enabled = false
      sign_in(admin)

      get "/admin/plugins/discourse-discord-events/status.json"

      expect(response.status).to eq(404)
    end
  end

  describe "#test_connection" do
    before { sign_in(admin) }

    it "reports success with the event count" do
      stub_request(:get, list_url).to_return(status: 200, body: [{ "id" => "1" }].to_json)

      post "/admin/plugins/discourse-discord-events/test-connection.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["success"]).to eq("OK")
      expect(response.parsed_body["event_count"]).to eq(1)
    end

    it "returns a friendly message for authentication failures" do
      stub_request(:get, list_url).to_return(status: 401, body: "{}")

      post "/admin/plugins/discourse-discord-events/test-connection.json"

      expect(response.status).to eq(422)
      expect(response.parsed_body["error"]).to eq(I18n.t("discord_events.errors.authentication"))
    end

    it "returns a friendly message when unconfigured" do
      SiteSetting.discord_events_guild_id = ""

      post "/admin/plugins/discourse-discord-events/test-connection.json"

      expect(response.status).to eq(422)
      expect(response.parsed_body["error"]).to eq(I18n.t("discord_events.errors.configuration"))
    end

    it "requires an admin" do
      sign_in(user)

      post "/admin/plugins/discourse-discord-events/test-connection.json"

      expect(response.status).to eq(404)
    end
  end

  describe "#sync" do
    it "enqueues a manual sync" do
      sign_in(admin)
      Jobs.run_later!

      expect_enqueued_with(job: Jobs::DiscourseDiscordEvents::SyncScheduledEvents) do
        post "/admin/plugins/discourse-discord-events/sync.json"
      end
      expect(response.status).to eq(200)
    end

    it "requires an admin" do
      sign_in(user)

      post "/admin/plugins/discourse-discord-events/sync.json"

      expect(response.status).to eq(404)
    end
  end

  describe "#clear_cache" do
    it "removes cached events and sync state" do
      sign_in(admin)
      Fabricate.times(2, :discord_event)
      DiscourseDiscordEvents::SyncStatus.record_start

      delete "/admin/plugins/discourse-discord-events/cache.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["deleted"]).to eq(2)
      expect(DiscourseDiscordEvents::Event.count).to eq(0)
      expect(DiscourseDiscordEvents::SyncStatus.current).to eq({})
    end

    it "requires an admin" do
      sign_in(user)

      delete "/admin/plugins/discourse-discord-events/cache.json"

      expect(response.status).to eq(404)
    end
  end
end
