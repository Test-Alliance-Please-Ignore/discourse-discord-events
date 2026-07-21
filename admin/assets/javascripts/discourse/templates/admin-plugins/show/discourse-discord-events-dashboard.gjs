import AdminDiscordEventsDashboard from "discourse/plugins/discourse-discord-events/discourse/components/admin-discord-events-dashboard";

export default <template>
  <AdminDiscordEventsDashboard @initialStatus={{@controller.model}} />
</template>
