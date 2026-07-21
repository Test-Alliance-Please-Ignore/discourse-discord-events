import { withPluginApi } from "discourse/lib/plugin-api";

const PLUGIN_ID = "discourse-discord-events";

export default {
  name: "discord-events-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.setAdminPluginIcon(PLUGIN_ID, "calendar-days");
      api.addAdminPluginConfigurationNav(PLUGIN_ID, [
        {
          label: "admin.discord_events.dashboard.title",
          route: "adminPlugins.show.discourse-discord-events-dashboard",
          description: "admin.discord_events.dashboard.nav_description",
        },
      ]);
    });
  },
};
