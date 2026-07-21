# frozen_string_literal: true

module ::DiscourseDiscordEvents
  class EventsController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    PER_PAGE = 24
    MAX_PAGE = 1000

    def index
      filter = params[:filter] == "past" ? :past : :upcoming
      page = params[:page].to_i.clamp(0, MAX_PAGE)
      sort = allowed_sort(params[:sort])

      scope = Event.public_send(filter).search(params[:q]).sorted(sort)
      total = scope.count
      events = scope.offset(page * PER_PAGE).limit(PER_PAGE)

      render json: {
               events: serialize_data(events, EventListSerializer),
               meta: {
                 page: page,
                 per_page: PER_PAGE,
                 total: total,
                 more: (page + 1) * PER_PAGE < total,
                 filter: filter,
                 sort: sort,
               },
             }
    end

    def show
      event = Event.find_by(id: params[:id])
      raise Discourse::NotFound if event.nil?

      render_serialized(event, EventSerializer, root: "event")
    end

    private

    def allowed_sort(value)
      return value if Event::SORT_ORDERS.key?(value)

      SiteSetting.discord_events_default_sort
    end
  end
end
