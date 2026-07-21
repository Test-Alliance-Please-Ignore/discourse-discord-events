# frozen_string_literal: true

# name: discourse-discord-events
# about: Displays Discord Scheduled Events from a Discord guild inside Discourse. Read-only; Discord remains the single source of truth.
# version: 0.1.0
# authors: Maximilian Praeger
# url: https://github.com/mcp/discourse-discord-events
# required_version: 2.7.0

enabled_site_setting :discord_events_enabled

register_asset "stylesheets/common/discord-events.scss"

register_svg_icon "calendar-days"
register_svg_icon "arrows-rotate"
register_svg_icon "location-pin"
register_svg_icon "clock"
register_svg_icon "user"
register_svg_icon "trash-can"
register_svg_icon "plug"
register_svg_icon "up-right-from-square"
register_svg_icon "chevron-left"

module ::DiscourseDiscordEvents
  PLUGIN_NAME = "discourse-discord-events"
end

require_relative "lib/discourse_discord_events/engine"

after_initialize do
  # route: /admin/plugins/discourse-discord-events
  add_admin_route("discord_events.admin.title", "discourse-discord-events", use_new_show_route: true)
end
