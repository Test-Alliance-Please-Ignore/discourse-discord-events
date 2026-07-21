# frozen_string_literal: true

RSpec.describe DiscourseDiscordEvents::AdminStatus do
  subject(:status) { described_class.build }

  before do
    enable_current_plugin
    SiteSetting.discord_events_bot_token = "token"
    SiteSetting.discord_events_guild_id = "guild"
    DiscourseDiscordEvents::SyncStatus.reset!
  end

  after do
    DiscourseDiscordEvents::SyncStatus.reset!
    DiscourseDiscordEvents::Discord::RateLimiter.new.reset!
  end

  it "reports configuration state" do
    expect(status.enabled).to eq(true)
    expect(status.configured).to eq(true)
    expect(status.guild_id).to eq("guild")
  end

  it "reports unconfigured when the token is missing" do
    SiteSetting.discord_events_bot_token = ""

    expect(status.configured).to eq(false)
  end

  it "counts cached events by bucket" do
    Fabricate(:discord_event, scheduled_start_time: 1.day.from_now)
    Fabricate(:discord_event, status: :completed, scheduled_start_time: 2.days.ago)

    expect(status.cached_event_count).to eq(2)
    expect(status.upcoming_event_count).to eq(1)
    expect(status.past_event_count).to eq(1)
  end

  describe "#next_sync_at" do
    it "is nil when synchronization is disabled" do
      SiteSetting.discord_events_sync_enabled = false

      expect(status.next_sync_at).to be_nil
    end

    it "projects from the last started sync" do
      SiteSetting.discord_events_sync_enabled = true
      SiteSetting.discord_events_sync_interval_minutes = 30

      freeze_time do
        DiscourseDiscordEvents::SyncStatus.record_start

        expect(Time.iso8601(status.next_sync_at)).to be_within(1.second).of(
          30.minutes.from_now,
        )
      end
    end

    it "never returns a time in the past" do
      SiteSetting.discord_events_sync_enabled = true
      DiscourseDiscordEvents::SyncStatus.record_start

      freeze_time(2.hours.from_now) do
        expect(Time.iso8601(described_class.build.next_sync_at)).to be_within(
          1.second,
        ).of(Time.zone.now)
      end
    end
  end

  it "reports rate limiting" do
    expect(status.rate_limited).to eq(false)

    DiscourseDiscordEvents::Discord::RateLimiter.new.record_rate_limit!(60)

    expect(described_class.build.rate_limited).to eq(true)
  end
end
