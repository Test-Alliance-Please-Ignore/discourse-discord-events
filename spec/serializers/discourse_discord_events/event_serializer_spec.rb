# frozen_string_literal: true

RSpec.describe DiscourseDiscordEvents::EventSerializer do
  before { enable_current_plugin }

  it "adds the full description and creator to the list attributes" do
    event =
      Fabricate(
        :discord_event,
        description: "d" * 500,
        creator_name: "Botty",
      )

    json = described_class.new(event, scope: Guardian.new, root: false).as_json

    expect(json[:description]).to eq("d" * 500)
    expect(json[:creator_name]).to eq("Botty")
    expect(json[:synced_at]).to be_present
    expect(json.keys).not_to include(:raw_json)
  end
end
