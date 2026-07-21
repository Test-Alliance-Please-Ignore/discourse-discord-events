# frozen_string_literal: true

module ::DiscourseDiscordEvents
  class EventSerializer < EventListSerializer
    attributes :description, :creator_name, :synced_at
  end
end
