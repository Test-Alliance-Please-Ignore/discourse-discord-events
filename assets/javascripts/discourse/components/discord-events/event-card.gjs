import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import EventDates from "./event-dates";
import StatusBadge from "./status-badge";

export default class EventCard extends Component {
  get participantLabel() {
    return i18n("discord_events.participants", {
      count: this.args.event.participant_count,
    });
  }

  <template>
    <article class="discord-events__card">
      <LinkTo
        @route="discord-events.show"
        @model={{@event.id}}
        class="discord-events__card-link"
      >
        <div class="discord-events__card-media">
          {{#if @event.image_url}}
            <img
              src={{@event.image_url}}
              alt=""
              loading="lazy"
              class="discord-events__card-image"
            />
          {{else}}
            <div class="discord-events__card-placeholder" aria-hidden="true">
              {{dIcon "calendar-days"}}
            </div>
          {{/if}}
        </div>

        <div class="discord-events__card-body">
          <header class="discord-events__card-header">
            <h3 class="discord-events__card-title">{{@event.name}}</h3>
            <StatusBadge @status={{@event.status}} />
          </header>

          <EventDates @event={{@event}} />

          {{#if @event.location}}
            <span class="discord-events__location">
              {{dIcon "location-pin"}}
              {{@event.location}}
            </span>
          {{/if}}

          {{#if @event.participant_count}}
            <span class="discord-events__participants">
              {{dIcon "user"}}
              {{this.participantLabel}}
            </span>
          {{/if}}

          {{#if @event.excerpt}}
            <p class="discord-events__excerpt">{{@event.excerpt}}</p>
          {{/if}}
        </div>
      </LinkTo>
    </article>
  </template>
}
