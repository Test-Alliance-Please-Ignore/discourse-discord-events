# frozen_string_literal: true

RSpec.describe DiscourseDiscordEvents::EventListSerializer do
  before { enable_current_plugin }

  def serialize(event)
    described_class.new(event, scope: Guardian.new, root: false).as_json
  end

  it "serializes the list attributes" do
    event = Fabricate(:discord_event, name: "Movie Night")

    json = serialize(event)

    expect(json[:name]).to eq("Movie Night")
    expect(json[:discord_url]).to eq(event.discord_url)
    expect(json[:status]).to eq("scheduled")
    expect(json[:entity_type]).to eq("external")
    expect(json.keys).not_to include(:description, :raw_json, :guild_id)
  end

  it "truncates the description into an excerpt" do
    event = Fabricate(:discord_event, description: "a" * 500)

    expect(serialize(event)[:excerpt].length).to be <= 200
  end

  it "omits the excerpt when there is no description" do
    event = Fabricate(:discord_event, description: nil)

    expect(serialize(event).keys).not_to include(:excerpt)
  end
end
