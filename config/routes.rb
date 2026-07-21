# frozen_string_literal: true

DiscourseDiscordEvents::Engine.routes.draw do
  get "/discord-events" => "events#index"
  get "/discord-events/:id" => "events#show", :constraints => { id: /\d+/ }
end

Discourse::Application.routes.draw do
  mount ::DiscourseDiscordEvents::Engine, at: "/"

  scope "/admin/plugins/discourse-discord-events", constraints: StaffConstraint.new do
    get "/status" => "discourse_discord_events/admin_discord_events#status"
    post "/test-connection" => "discourse_discord_events/admin_discord_events#test_connection"
    post "/sync" => "discourse_discord_events/admin_discord_events#sync"
    delete "/cache" => "discourse_discord_events/admin_discord_events#clear_cache"
  end
end
