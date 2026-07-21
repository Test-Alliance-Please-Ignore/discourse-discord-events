import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

const SORT_OPTIONS = [
  "start_time_asc",
  "start_time_desc",
  "name_asc",
  "recently_synced",
];

export default class ListControls extends Component {
  sortOptions = SORT_OPTIONS;

  get currentSort() {
    return this.args.sort || this.args.defaultSort;
  }

  @action
  onSearchInput(event) {
    if (event.key === "Enter") {
      this.args.onSearch(event.target.value);
    }
  }

  @action
  onSearchChange(event) {
    this.args.onSearch(event.target.value);
  }

  @action
  onSortChange(event) {
    this.args.onChangeSort(event.target.value);
  }

  <template>
    <div class="discord-events__controls">
      <nav
        class="discord-events__filters"
        aria-label={{i18n "discord_events.filter_label"}}
      >
        <DButton
          @translatedLabel={{i18n "discord_events.upcoming"}}
          @action={{fn @onChangeFilter "upcoming"}}
          class={{if (eq @filter "upcoming") "btn-primary" "btn-default"}}
          aria-pressed={{if (eq @filter "upcoming") "true" "false"}}
        />
        <DButton
          @translatedLabel={{i18n "discord_events.past"}}
          @action={{fn @onChangeFilter "past"}}
          class={{if (eq @filter "past") "btn-primary" "btn-default"}}
          aria-pressed={{if (eq @filter "past") "true" "false"}}
        />
      </nav>

      <input
        type="search"
        class="discord-events__search"
        value={{@q}}
        placeholder={{i18n "discord_events.search_placeholder"}}
        aria-label={{i18n "discord_events.search_placeholder"}}
        {{on "keydown" this.onSearchInput}}
        {{on "change" this.onSearchChange}}
      />

      <label class="discord-events__sort">
        <span>{{i18n "discord_events.sort.label"}}</span>
        <select {{on "change" this.onSortChange}}>
          {{#each this.sortOptions as |sortOption|}}
            <option
              value={{sortOption}}
              selected={{eq this.currentSort sortOption}}
            >{{i18n (concat "discord_events.sort." sortOption)}}</option>
          {{/each}}
        </select>
      </label>
    </div>
  </template>
}
