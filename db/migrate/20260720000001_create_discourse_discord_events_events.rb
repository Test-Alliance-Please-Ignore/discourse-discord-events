# frozen_string_literal: true

class CreateDiscourseDiscordEventsEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :discourse_discord_events_events do |t|
      t.string :discord_event_id, null: false
      t.string :guild_id, null: false
      t.string :name, null: false
      t.text :description
      t.string :image_url
      t.integer :status, null: false, default: 1
      t.integer :entity_type, null: false, default: 3
      t.string :location
      t.string :external_url
      t.string :creator_name
      t.integer :participant_count
      t.integer :privacy_level, null: false, default: 2
      t.datetime :scheduled_start_time, null: false
      t.datetime :scheduled_end_time
      t.jsonb :raw_json, null: false, default: {}
      t.datetime :synced_at, null: false
      t.timestamps
    end

    add_index :discourse_discord_events_events, :discord_event_id, unique: true
    add_index :discourse_discord_events_events, :guild_id
    add_index :discourse_discord_events_events, %i[status scheduled_start_time]
    add_index :discourse_discord_events_events, :scheduled_start_time
  end
end
