import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import EventCard from "discourse/plugins/discourse-discord-events/discourse/components/discord-events/event-card";
import ListControls from "discourse/plugins/discourse-discord-events/discourse/components/discord-events/list-controls";

export default <template>
  <section class="discord-events">
    <header class="discord-events__header">
      <h1>{{i18n "discord_events.title"}}</h1>
    </header>

    <ListControls
      @filter={{@controller.filter}}
      @q={{@controller.q}}
      @sort={{@controller.sort}}
      @defaultSort={{@controller.model.meta.sort}}
      @onChangeFilter={{@controller.changeFilter}}
      @onSearch={{@controller.search}}
      @onChangeSort={{@controller.changeSort}}
    />

    {{#if @controller.model.events.length}}
      <div class="discord-events__list">
        {{#each @controller.model.events as |event|}}
          <EventCard @event={{event}} />
        {{/each}}
      </div>

      {{#if @controller.showPagination}}
        <nav
          class="discord-events__pagination"
          aria-label={{i18n "discord_events.pagination_label"}}
        >
          <DButton
            @translatedLabel={{i18n "discord_events.previous_page"}}
            @action={{@controller.previousPage}}
            @disabled={{@controller.isFirstPage}}
            class="btn-default"
          />
          <span class="discord-events__page-info">
            {{i18n
              "discord_events.page_info"
              page=@controller.currentPageDisplay
              total=@controller.totalPages
            }}
          </span>
          <DButton
            @translatedLabel={{i18n "discord_events.next_page"}}
            @action={{@controller.nextPage}}
            @disabled={{@controller.isLastPage}}
            class="btn-default"
          />
        </nav>
      {{/if}}
    {{else}}
      <p class="discord-events__empty">{{i18n "discord_events.no_events"}}</p>
    {{/if}}
  </section>
</template>
