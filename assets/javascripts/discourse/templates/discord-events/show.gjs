import { LinkTo } from "@ember/routing";
import DButton from "discourse/ui-kit/d-button";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import EventDates from "discourse/plugins/discourse-discord-events/discourse/components/discord-events/event-dates";
import StatusBadge from "discourse/plugins/discourse-discord-events/discourse/components/discord-events/status-badge";

export default <template>
  <article class="discord-events discord-events__detail">
    <nav class="discord-events__breadcrumbs">
      <LinkTo @route="discord-events.index" class="discord-events__back">
        {{dIcon "chevron-left"}}
        {{i18n "discord_events.back_to_list"}}
      </LinkTo>
    </nav>

    {{#if @controller.model.image_url}}
      <div class="discord-events__hero">
        <img src={{@controller.model.image_url}} alt="" />
      </div>
    {{/if}}

    <header class="discord-events__detail-header">
      <h1>{{@controller.model.name}}</h1>
      <StatusBadge @status={{@controller.model.status}} />
    </header>

    <dl class="discord-events__meta">
      <dt>{{dIcon "clock"}} {{i18n "discord_events.when"}}</dt>
      <dd><EventDates @event={{@controller.model}} /></dd>

      {{#if @controller.model.location}}
        <dt>{{dIcon "location-pin"}} {{i18n "discord_events.where"}}</dt>
        <dd>
          {{#if @controller.model.external_url}}
            <a
              href={{@controller.model.external_url}}
              rel="noopener noreferrer"
              target="_blank"
            >{{@controller.model.location}}</a>
          {{else}}
            {{@controller.model.location}}
          {{/if}}
        </dd>
      {{/if}}

      {{#if @controller.model.creator_name}}
        <dt>{{dIcon "user"}} {{i18n "discord_events.hosted_by"}}</dt>
        <dd>{{@controller.model.creator_name}}</dd>
      {{/if}}

      {{#if @controller.model.participant_count}}
        <dt>{{dIcon "user"}} {{i18n "discord_events.interest"}}</dt>
        <dd>{{i18n
            "discord_events.participants"
            count=@controller.model.participant_count
          }}</dd>
      {{/if}}
    </dl>

    {{#if @controller.model.description}}
      <div class="discord-events__description">
        <p>{{@controller.model.description}}</p>
      </div>
    {{/if}}

    <footer class="discord-events__detail-footer">
      <DButton
        @translatedLabel={{i18n "discord_events.open_in_discord"}}
        @icon="up-right-from-square"
        @href={{@controller.model.discord_url}}
        rel="noopener noreferrer"
        target="_blank"
        class="btn-primary discord-events__discord-link"
      />
      {{#if @controller.model.synced_at}}
        <span class="discord-events__synced-at">
          {{i18n "discord_events.last_synced"}}
          {{dFormatDate @controller.model.synced_at leaveAgo="true"}}
        </span>
      {{/if}}
    </footer>
  </article>
</template>
