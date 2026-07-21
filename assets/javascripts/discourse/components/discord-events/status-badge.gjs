import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

export default class StatusBadge extends Component {
  get label() {
    return i18n(`discord_events.status.${this.args.status}`);
  }

  <template>
    <span
      class={{dConcatClass "discord-events__status-badge" (concat "-" @status)}}
    >{{this.label}}</span>
  </template>
}
