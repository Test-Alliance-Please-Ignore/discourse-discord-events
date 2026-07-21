import getURL from "discourse/lib/get-url";
import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";

export default {
  name: "discord-events-navigation",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (
      !siteSettings.discord_events_enabled ||
      !siteSettings.discord_events_top_menu
    ) {
      return;
    }

    withPluginApi((api) => {
      api.addNavigationBarItem({
        name: "discord-events",
        displayName: i18n("discord_events.title"),
        href: getURL("/discord-events"),
      });
    });
  },
};
