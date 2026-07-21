import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminPluginsShowDiscourseDiscordEventsDashboardRoute extends DiscourseRoute {
  model() {
    return ajax("/admin/plugins/discourse-discord-events/status.json");
  }

  titleToken() {
    return i18n("admin.discord_events.dashboard.title");
  }
}
