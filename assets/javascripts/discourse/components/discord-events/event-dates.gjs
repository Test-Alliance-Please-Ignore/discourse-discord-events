import Component from "@glimmer/component";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class EventDates extends Component {
  get start() {
    return moment(this.args.event.scheduled_start_time).format("LLL");
  }

  get end() {
    const end = this.args.event.scheduled_end_time;
    return end ? moment(end).format("LLL") : null;
  }

  <template>
    <span class="discord-events__dates">
      {{dIcon "clock"}}
      <time
        datetime={{@event.scheduled_start_time}}
        class="discord-events__start"
      >{{this.start}}</time>
      {{#if this.end}}
        <span aria-hidden="true">–</span>
        <span class="sr-only">{{i18n "discord_events.until"}}</span>
        <time
          datetime={{@event.scheduled_end_time}}
          class="discord-events__end"
        >{{this.end}}</time>
      {{/if}}
    </span>
  </template>
}
