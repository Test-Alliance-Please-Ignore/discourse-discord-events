import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class DiscordEventsIndexRoute extends DiscourseRoute {
  queryParams = {
    filter: { refreshModel: true },
    q: { refreshModel: true, replace: true },
    sort: { refreshModel: true },
    page: { refreshModel: true },
  };

  model(params) {
    return ajax("/discord-events.json", {
      data: {
        filter: params.filter,
        q: params.q,
        sort: params.sort,
        page: params.page,
      },
    });
  }

  titleToken() {
    return i18n("discord_events.title");
  }
}
