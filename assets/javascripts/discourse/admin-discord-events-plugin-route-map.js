export default {
  resource: "admin.adminPlugins.show",

  path: "/plugins",

  map() {
    this.route("discourse-discord-events-dashboard", { path: "dashboard" });
  },
};
