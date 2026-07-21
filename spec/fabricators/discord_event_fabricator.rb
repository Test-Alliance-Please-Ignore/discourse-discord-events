# frozen_string_literal: true

Fabricator(:discord_event, from: "DiscourseDiscordEvents::Event") do
  discord_event_id { sequence(:discord_event_id) { |i| (100_000_000 + i).to_s } }
  guild_id "987654321098765432"
  name { sequence(:name) { |i| "Community Event #{i}" } }
  description "A regular community gathering."
  status :scheduled
  entity_type :external
  privacy_level :guild_only
  location "Main Stage"
  creator_name "event_bot"
  participant_count 5
  scheduled_start_time { 1.day.from_now }
  scheduled_end_time { 1.day.from_now + 2.hours }
  raw_json { {} }
  synced_at { Time.zone.now }
end
