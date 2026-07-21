# frozen_string_literal: true

module ::DiscourseDiscordEvents
  class EventListSerializer < ApplicationSerializer
    EXCERPT_LENGTH = 200

    attributes :id,
               :name,
               :excerpt,
               :image_url,
               :status,
               :entity_type,
               :location,
               :external_url,
               :participant_count,
               :scheduled_start_time,
               :scheduled_end_time,
               :discord_url

    def excerpt
      object.description&.truncate(EXCERPT_LENGTH)
    end

    def include_excerpt?
      object.description.present?
    end
  end
end
