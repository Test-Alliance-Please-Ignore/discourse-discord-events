# frozen_string_literal: true

module ::DiscourseDiscordEvents
  class Event < ActiveRecord::Base
    self.table_name = "discourse_discord_events_events"

    # Numeric values mirror Discord's scheduled event API constants so raw
    # API payloads map onto the enums without translation tables.
    enum :status, { scheduled: 1, active: 2, completed: 3, canceled: 4 }
    enum :entity_type, { stage_instance: 1, voice: 2, external: 3 }, prefix: :entity
    enum :privacy_level, { guild_only: 2 }, prefix: :privacy

    SORT_ORDERS = {
      "start_time_asc" => { scheduled_start_time: :asc, id: :asc },
      "start_time_desc" => { scheduled_start_time: :desc, id: :desc },
      "name_asc" => { name: :asc, id: :asc },
      "recently_synced" => { synced_at: :desc, id: :desc },
    }.freeze

    validates :discord_event_id, presence: true, uniqueness: true
    validates :guild_id, presence: true
    validates :name, presence: true, length: { maximum: 100 }
    validates :description, length: { maximum: 5000 }
    validates :scheduled_start_time, presence: true
    validates :participant_count, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

    scope :upcoming, -> do
      where(status: :active).or(
        where(status: :scheduled).where("scheduled_start_time >= ?", Time.zone.now),
      )
    end

    scope :past, -> do
      where(status: %i[completed canceled]).or(
        where(status: :scheduled).where("scheduled_start_time < ?", Time.zone.now),
      )
    end

    scope :search, ->(term) do
      if term.present?
        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(term.strip)}%"
        where("name ILIKE :pattern OR description ILIKE :pattern", pattern:)
      end
    end

    scope :sorted, ->(order) { order(SORT_ORDERS.fetch(order.to_s, SORT_ORDERS["start_time_asc"])) }

    def self.prune_to_limit(limit)
      excess = count - limit
      return 0 if excess <= 0

      # Drop the oldest finished events first; never prune upcoming ones.
      prunable = where(status: %i[completed canceled]).order(scheduled_start_time: :asc, id: :asc).limit(excess).pluck(:id)
      where(id: prunable).delete_all
    end

    def discord_url
      "https://discord.com/events/#{guild_id}/#{discord_event_id}"
    end

    def finished?
      completed? || canceled?
    end
  end
end

# == Schema Information
#
# Table name: discourse_discord_events_events
#
#  id                   :bigint           not null, primary key
#  discord_event_id     :string           not null
#  guild_id             :string           not null
#  name                 :string           not null
#  description          :text
#  image_url            :string
#  status               :integer          default("scheduled"), not null
#  entity_type          :integer          default("external"), not null
#  location             :string
#  external_url         :string
#  creator_name         :string
#  participant_count    :integer
#  privacy_level        :integer          default("guild_only"), not null
#  scheduled_start_time :datetime         not null
#  scheduled_end_time   :datetime
#  raw_json             :jsonb            not null
#  synced_at            :datetime         not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
# Indexes
#
#  idx_on_discord_event_id  (discord_event_id) UNIQUE
#  idx_on_guild_id          (guild_id)
#  idx_on_status_start      (status,scheduled_start_time)
#  idx_on_start             (scheduled_start_time)
#
