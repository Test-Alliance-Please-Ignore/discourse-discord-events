# frozen_string_literal: true

RSpec.describe DiscourseDiscordEvents::Event do
  before { enable_current_plugin }

  describe "validations" do
    it "requires the core attributes" do
      event = described_class.new

      expect(event).not_to be_valid
      expect(event.errors[:discord_event_id]).to be_present
      expect(event.errors[:guild_id]).to be_present
      expect(event.errors[:name]).to be_present
      expect(event.errors[:scheduled_start_time]).to be_present
    end

    it "rejects duplicate discord_event_ids" do
      existing = Fabricate(:discord_event)
      copy = Fabricate.build(:discord_event, discord_event_id: existing.discord_event_id)

      expect(copy).not_to be_valid
      expect(copy.errors[:discord_event_id]).to be_present
    end

    it "rejects names longer than Discord's 100 character limit" do
      event = Fabricate.build(:discord_event, name: "a" * 101)

      expect(event).not_to be_valid
    end

    it "rejects negative participant counts" do
      event = Fabricate.build(:discord_event, participant_count: -1)

      expect(event).not_to be_valid
    end
  end

  describe "enums" do
    it "maps Discord's numeric status constants" do
      expect(described_class.statuses).to eq(
        "scheduled" => 1,
        "active" => 2,
        "completed" => 3,
        "canceled" => 4,
      )
    end

    it "maps Discord's numeric entity type constants" do
      expect(described_class.entity_types).to eq("stage_instance" => 1, "voice" => 2, "external" => 3)
    end
  end

  describe ".upcoming" do
    it "includes future scheduled and currently active events only" do
      future = Fabricate(:discord_event, scheduled_start_time: 2.days.from_now)
      active = Fabricate(:discord_event, status: :active, scheduled_start_time: 1.hour.ago)
      stale = Fabricate(:discord_event, scheduled_start_time: 1.day.ago)
      done = Fabricate(:discord_event, status: :completed, scheduled_start_time: 3.days.ago)

      expect(described_class.upcoming).to contain_exactly(future, active)
      expect(described_class.upcoming).not_to include(stale, done)
    end
  end

  describe ".past" do
    it "includes completed, canceled, and stale scheduled events" do
      future = Fabricate(:discord_event, scheduled_start_time: 2.days.from_now)
      stale = Fabricate(:discord_event, scheduled_start_time: 1.day.ago)
      done = Fabricate(:discord_event, status: :completed, scheduled_start_time: 3.days.ago)
      canceled = Fabricate(:discord_event, status: :canceled, scheduled_start_time: 4.days.ago)

      expect(described_class.past).to contain_exactly(stale, done, canceled)
      expect(described_class.past).not_to include(future)
    end
  end

  describe ".search" do
    it "matches name and description case-insensitively" do
      by_name = Fabricate(:discord_event, name: "Movie Night")
      by_description = Fabricate(:discord_event, description: "We watch a movie together")
      Fabricate(:discord_event, name: "Game Session", description: "Board games")

      expect(described_class.search("movie")).to contain_exactly(by_name, by_description)
    end

    it "escapes SQL LIKE wildcards in the term" do
      literal = Fabricate(:discord_event, name: "100% official meetup")
      Fabricate(:discord_event, name: "unofficial meetup")

      expect(described_class.search("100%")).to contain_exactly(literal)
    end

    it "returns everything for a blank term" do
      Fabricate(:discord_event)

      expect(described_class.search("").count).to eq(1)
      expect(described_class.search(nil).count).to eq(1)
    end
  end

  describe ".sorted" do
    it "orders by the requested sort key" do
      later = Fabricate(:discord_event, name: "B", scheduled_start_time: 3.days.from_now)
      earlier = Fabricate(:discord_event, name: "A", scheduled_start_time: 1.day.from_now)

      expect(described_class.sorted("start_time_asc")).to eq([earlier, later])
      expect(described_class.sorted("start_time_desc")).to eq([later, earlier])
      expect(described_class.sorted("name_asc")).to eq([earlier, later])
    end

    it "falls back to start_time_asc for unknown sort keys" do
      later = Fabricate(:discord_event, scheduled_start_time: 3.days.from_now)
      earlier = Fabricate(:discord_event, scheduled_start_time: 1.day.from_now)

      expect(described_class.sorted("nonsense")).to eq([earlier, later])
    end
  end

  describe ".prune_to_limit" do
    it "removes the oldest finished events beyond the limit" do
      old_done =
        Fabricate(:discord_event, status: :completed, scheduled_start_time: 10.days.ago)
      recent_done =
        Fabricate(:discord_event, status: :completed, scheduled_start_time: 2.days.ago)
      upcoming = Fabricate(:discord_event, scheduled_start_time: 1.day.from_now)

      expect(described_class.prune_to_limit(2)).to eq(1)
      expect(described_class.all).to contain_exactly(recent_done, upcoming)
      expect { old_done.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "never prunes upcoming events, even over the limit" do
      Fabricate.times(3, :discord_event, scheduled_start_time: 1.day.from_now)

      expect(described_class.prune_to_limit(1)).to eq(0)
      expect(described_class.count).to eq(3)
    end

    it "is a no-op when under the limit" do
      Fabricate(:discord_event)

      expect(described_class.prune_to_limit(10)).to eq(0)
    end
  end

  describe "#discord_url" do
    it "builds the public Discord event URL" do
      event = Fabricate(:discord_event, guild_id: "1", discord_event_id: "2")

      expect(event.discord_url).to eq("https://discord.com/events/1/2")
    end
  end
end
