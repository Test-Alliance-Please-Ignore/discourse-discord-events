# frozen_string_literal: true

RSpec.describe DiscourseDiscordEvents::Discord::Synchronizer do
  subject(:synchronizer) { described_class.new }

  let(:guild_id) { "987654321098765432" }
  let(:list_url) do
    "https://discord.com/api/v10/guilds/#{guild_id}/scheduled-events?with_user_count=true"
  end

  def event_payload(id:, **overrides)
    {
      "id" => id,
      "guild_id" => guild_id,
      "name" => "Movie Night #{id}",
      "description" => "Bring popcorn",
      "status" => 1,
      "entity_type" => 3,
      "privacy_level" => 2,
      "entity_metadata" => {
        "location" => "The Lounge",
      },
      "creator" => {
        "username" => "botty",
        "global_name" => "Botty",
      },
      "user_count" => 12,
      "image" => "abc123DEF",
      "scheduled_start_time" => 2.days.from_now.iso8601,
      "scheduled_end_time" => 2.days.from_now.iso8601,
    }.merge(overrides)
  end

  def stub_list(events)
    stub_request(:get, list_url).to_return(status: 200, body: events.to_json)
  end

  before do
    enable_current_plugin
    SiteSetting.discord_events_bot_token = "test-token"
    SiteSetting.discord_events_guild_id = guild_id
    DiscourseDiscordEvents::SyncStatus.reset!
  end

  after { DiscourseDiscordEvents::Discord::RateLimiter.new.reset! }

  describe "#sync!" do
    it "creates cached events from the API payload" do
      stub_list([event_payload(id: "111"), event_payload(id: "222")])

      result = synchronizer.sync!

      expect(result.created).to eq(2)
      event = DiscourseDiscordEvents::Event.find_by(discord_event_id: "111")
      expect(event.name).to eq("Movie Night 111")
      expect(event.description).to eq("Bring popcorn")
      expect(event.location).to eq("The Lounge")
      expect(event.creator_name).to eq("Botty")
      expect(event.participant_count).to eq(12)
      expect(event.image_url).to eq(
        "https://cdn.discordapp.com/guild-events/111/abc123DEF.png?size=1024",
      )
      expect(event.status).to eq("scheduled")
      expect(event.entity_type).to eq("external")
      expect(event.raw_json["id"]).to eq("111")
      expect(event.synced_at).to be_present
    end

    it "is idempotent across repeated runs" do
      stub_list([event_payload(id: "111")])

      synchronizer.sync!
      result = described_class.sync!

      expect(DiscourseDiscordEvents::Event.count).to eq(1)
      expect(result.created).to eq(0)
      expect(result.updated).to eq(0)
    end

    it "updates events whose attributes changed" do
      stub_list([event_payload(id: "111")])
      synchronizer.sync!

      stub_list([event_payload(id: "111", "name" => "Renamed Event", "user_count" => 99)])
      result = described_class.sync!

      expect(result.updated).to eq(1)
      event = DiscourseDiscordEvents::Event.find_by(discord_event_id: "111")
      expect(event.name).to eq("Renamed Event")
      expect(event.participant_count).to eq(99)
    end

    it "does not touch rows when nothing changed" do
      stub_list([event_payload(id: "111")])
      synchronizer.sync!
      original_synced_at = DiscourseDiscordEvents::Event.first.synced_at

      freeze_time(1.hour.from_now) do
        described_class.sync!

        expect(DiscourseDiscordEvents::Event.first.synced_at).to eq_time(original_synced_at)
      end
    end

    it "marks started events that vanished from the API as completed" do
      active = Fabricate(:discord_event, guild_id: guild_id, status: :active)
      stale =
        Fabricate(:discord_event, guild_id: guild_id, scheduled_start_time: 1.hour.ago)
      stub_list([])

      result = synchronizer.sync!

      expect(result.completed).to eq(2)
      expect(active.reload.status).to eq("completed")
      expect(stale.reload.status).to eq("completed")
    end

    it "deletes upcoming events that vanished from the API" do
      upcoming = Fabricate(:discord_event, guild_id: guild_id)
      stub_list([])

      result = synchronizer.sync!

      expect(result.deleted).to eq(1)
      expect(DiscourseDiscordEvents::Event.exists?(upcoming.id)).to eq(false)
    end

    it "leaves already-finished cached events untouched" do
      done = Fabricate(:discord_event, guild_id: guild_id, status: :completed)
      canceled = Fabricate(:discord_event, guild_id: guild_id, status: :canceled)
      stub_list([])

      result = synchronizer.sync!

      expect(result.completed).to eq(0)
      expect(result.deleted).to eq(0)
      expect(done.reload.status).to eq("completed")
      expect(canceled.reload.status).to eq("canceled")
    end

    it "removes events cached for a previously configured guild" do
      foreign = Fabricate(:discord_event, guild_id: "another-guild")
      stub_list([event_payload(id: "111")])

      synchronizer.sync!

      expect(DiscourseDiscordEvents::Event.exists?(foreign.id)).to eq(false)
      expect(DiscourseDiscordEvents::Event.where(discord_event_id: "111").count).to eq(1)
    end

    it "prunes finished events beyond the cache limit" do
      SiteSetting.discord_events_max_cached_events = 10
      Fabricate.times(
        12,
        :discord_event,
        guild_id: guild_id,
        status: :completed,
        scheduled_start_time: 3.days.ago,
      )
      stub_list([])

      result = synchronizer.sync!

      expect(result.pruned).to eq(2)
      expect(DiscourseDiscordEvents::Event.count).to eq(10)
    end

    it "skips malformed payloads without aborting the run" do
      stub_list(
        [
          event_payload(id: "111"),
          event_payload(id: "222", "scheduled_start_time" => "not-a-date"),
          event_payload(id: "333", "status" => 42),
          event_payload(id: nil),
        ],
      )

      result = synchronizer.sync!

      expect(result.created).to eq(1)
      expect(result.skipped).to eq(3)
      expect(DiscourseDiscordEvents::Event.pluck(:discord_event_id)).to eq(%w[111])
    end

    it "handles absent optional fields" do
      stub_list(
        [
          event_payload(
            id: "111",
            "description" => nil,
            "entity_metadata" => nil,
            "creator" => nil,
            "user_count" => nil,
            "image" => nil,
            "scheduled_end_time" => nil,
          ),
        ],
      )

      synchronizer.sync!

      event = DiscourseDiscordEvents::Event.find_by(discord_event_id: "111")
      expect(event.description).to be_nil
      expect(event.location).to be_nil
      expect(event.external_url).to be_nil
      expect(event.creator_name).to be_nil
      expect(event.image_url).to be_nil
      expect(event.scheduled_end_time).to be_nil
    end

    it "extracts an external URL when the location is a link" do
      stub_list(
        [
          event_payload(
            id: "111",
            "entity_metadata" => {
              "location" => "https://meet.example.com/room",
            },
          ),
        ],
      )

      synchronizer.sync!

      event = DiscourseDiscordEvents::Event.find_by(discord_event_id: "111")
      expect(event.location).to eq("https://meet.example.com/room")
      expect(event.external_url).to eq("https://meet.example.com/room")
    end

    it "rejects suspicious image hashes to avoid URL injection" do
      stub_list([event_payload(id: "111", "image" => "../../evil")])

      synchronizer.sync!

      expect(DiscourseDiscordEvents::Event.first.image_url).to be_nil
    end

    it "records success metrics and history" do
      stub_list([event_payload(id: "111")])

      synchronizer.sync!

      status = DiscourseDiscordEvents::SyncStatus.current
      expect(status["last_success_at"]).to be_present
      expect(status["last_error"]).to be_nil
      history = DiscourseDiscordEvents::SyncStatus.history
      expect(history.size).to eq(1)
      expect(history.first["success"]).to eq(true)
      expect(history.first["created"]).to eq(1)
    end

    it "records the failure and re-raises on API errors" do
      stub_request(:get, list_url).to_return(status: 401, body: "{}")

      expect { synchronizer.sync! }.to raise_error(
        DiscourseDiscordEvents::Discord::Errors::AuthenticationError,
      )

      status = DiscourseDiscordEvents::SyncStatus.current
      expect(status["last_error"]["error_class"]).to eq(
        "DiscourseDiscordEvents::Discord::Errors::AuthenticationError",
      )
      history = DiscourseDiscordEvents::SyncStatus.history
      expect(history.first["success"]).to eq(false)
    end

    it "leaves the cache untouched when Discord is down" do
      cached = Fabricate(:discord_event, guild_id: guild_id)
      stub_request(:get, list_url).to_return(status: 503, body: "")

      expect { synchronizer.sync! }.to raise_error(
        DiscourseDiscordEvents::Discord::Errors::ServerError,
      )
      expect(cached.reload).to be_present
    end
  end
end
