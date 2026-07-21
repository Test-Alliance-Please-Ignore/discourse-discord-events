import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class DiscordEventsShowRoute extends DiscourseRoute {
  async model(params) {
    const result = await ajax(`/discord-events/${params.id}.json`);
    return result.event;
  }

  titleToken() {
    return this.currentModel?.name;
  }
}
