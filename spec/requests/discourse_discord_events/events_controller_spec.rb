# frozen_string_literal: true

RSpec.describe DiscourseDiscordEvents::EventsController do
  fab!(:user)

  before { enable_current_plugin }

  describe "#index" do
    it "returns upcoming events by default, sorted by start time" do
      later = Fabricate(:discord_event, scheduled_start_time: 3.days.from_now)
      earlier = Fabricate(:discord_event, scheduled_start_time: 1.day.from_now)
      Fabricate(:discord_event, status: :completed, scheduled_start_time: 2.days.ago)

      get "/discord-events.json"

      expect(response.status).to eq(200)
      ids = response.parsed_body["events"].map { |event| event["id"] }
      expect(ids).to eq([earlier.id, later.id])
      expect(response.parsed_body["meta"]["filter"]).to eq("upcoming")
      expect(response.parsed_body["meta"]["total"]).to eq(2)
    end

    it "returns past events with filter=past" do
      Fabricate(:discord_event, scheduled_start_time: 1.day.from_now)
      done = Fabricate(:discord_event, status: :completed, scheduled_start_time: 2.days.ago)

      get "/discord-events.json", params: { filter: "past" }

      ids = response.parsed_body["events"].map { |event| event["id"] }
      expect(ids).to eq([done.id])
    end

    it "searches by name and description" do
      match = Fabricate(:discord_event, name: "Movie Night")
      Fabricate(:discord_event, name: "Game Session", description: "Board games")

      get "/discord-events.json", params: { q: "movie" }

      ids = response.parsed_body["events"].map { |event| event["id"] }
      expect(ids).to eq([match.id])
    end

    it "honors an explicit sort order" do
      later = Fabricate(:discord_event, scheduled_start_time: 3.days.from_now)
      earlier = Fabricate(:discord_event, scheduled_start_time: 1.day.from_now)

      get "/discord-events.json", params: { sort: "start_time_desc" }

      ids = response.parsed_body["events"].map { |event| event["id"] }
      expect(ids).to eq([later.id, earlier.id])
    end

    it "falls back to the default sort for invalid sort params" do
      Fabricate(:discord_event)

      get "/discord-events.json", params: { sort: "evil; DROP TABLE" }

      expect(response.status).to eq(200)
      expect(response.parsed_body["meta"]["sort"]).to eq(
        SiteSetting.discord_events_default_sort,
      )
    end

    it "paginates" do
      Fabricate.times(25, :discord_event)

      get "/discord-events.json"
      expect(response.parsed_body["events"].size).to eq(24)
      expect(response.parsed_body["meta"]["more"]).to eq(true)

      get "/discord-events.json", params: { page: 1 }
      expect(response.parsed_body["events"].size).to eq(1)
      expect(response.parsed_body["meta"]["more"]).to eq(false)
    end

    it "serializes list fields without the full description" do
      Fabricate(:discord_event, description: "x" * 500)

      get "/discord-events.json"

      event = response.parsed_body["events"].first
      expect(event["excerpt"].length).to be <= 200
      expect(event).not_to have_key("description")
      expect(event["discord_url"]).to be_present
    end

    it "is available to anonymous visitors on public sites" do
      Fabricate(:discord_event)

      get "/discord-events.json"

      expect(response.status).to eq(200)
    end

    it "requires login when the site is private" do
      SiteSetting.login_required = true

      get "/discord-events.json"

      expect(response.status).to eq(403)
    end

    it "404s when the plugin is disabled" do
      SiteSetting.discord_events_enabled = false

      get "/discord-events.json"

      expect(response.status).to eq(404)
    end
  end

  describe "#show" do
    fab!(:event) { Fabricate(:discord_event, description: "Full details here") }

    it "returns the full event" do
      get "/discord-events/#{event.id}.json"

      expect(response.status).to eq(200)
      payload = response.parsed_body["event"]
      expect(payload["id"]).to eq(event.id)
      expect(payload["description"]).to eq("Full details here")
      expect(payload["creator_name"]).to eq(event.creator_name)
    end

    it "404s for unknown events" do
      get "/discord-events/0.json"

      expect(response.status).to eq(404)
    end

    it "requires login when the site is private" do
      SiteSetting.login_required = true

      get "/discord-events/#{event.id}.json"

      expect(response.status).to eq(403)
    end
  end
end
