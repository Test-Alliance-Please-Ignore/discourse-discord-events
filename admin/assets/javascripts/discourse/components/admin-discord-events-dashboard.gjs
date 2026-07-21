import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const BASE_PATH = "/admin/plugins/discourse-discord-events";

export default class AdminDiscordEventsDashboard extends Component {
  @service dialog;

  @tracked refreshedStatus = null;
  @tracked busy = false;
  @tracked connectionResult = null;

  get status() {
    return this.refreshedStatus ?? this.args.initialStatus;
  }

  get lastError() {
    return this.status.last_error;
  }

  get statusRows() {
    const status = this.status;
    return [
      {
        label: i18n("admin.discord_events.dashboard.plugin_enabled"),
        ok: status.enabled,
      },
      {
        label: i18n("admin.discord_events.dashboard.sync_enabled"),
        ok: status.sync_enabled,
      },
      {
        label: i18n("admin.discord_events.dashboard.configured"),
        ok: status.configured,
      },
    ];
  }

  get lastDuration() {
    if (this.status.last_duration_ms == null) {
      return null;
    }
    return i18n("admin.discord_events.dashboard.duration_ms", {
      count: this.status.last_duration_ms,
    });
  }

  @action
  async refreshStatus() {
    try {
      this.refreshedStatus = await ajax(`${BASE_PATH}/status.json`);
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async testConnection() {
    this.busy = true;
    this.connectionResult = null;
    try {
      const result = await ajax(`${BASE_PATH}/test-connection`, {
        type: "POST",
      });
      this.connectionResult = {
        ok: true,
        message: i18n("admin.discord_events.dashboard.connection_ok", {
          count: result.event_count,
        }),
      };
    } catch (error) {
      const message =
        error.jqXHR?.responseJSON?.error ||
        i18n("admin.discord_events.dashboard.connection_failed");
      this.connectionResult = { ok: false, message };
    } finally {
      this.busy = false;
    }
  }

  @action
  async syncNow() {
    this.busy = true;
    try {
      await ajax(`${BASE_PATH}/sync`, { type: "POST" });
      this.dialog.alert(i18n("admin.discord_events.dashboard.sync_enqueued"));
      await this.refreshStatus();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.busy = false;
    }
  }

  @action
  clearCache() {
    this.dialog.deleteConfirm({
      message: i18n("admin.discord_events.dashboard.clear_cache_confirm"),
      didConfirm: async () => {
        try {
          await ajax(`${BASE_PATH}/cache`, { type: "DELETE" });
          await this.refreshStatus();
        } catch (error) {
          popupAjaxError(error);
        }
      },
    });
  }

  <template>
    <div class="discord-events-admin">
      <DPageSubheader
        @titleLabel={{i18n "admin.discord_events.dashboard.title"}}
        @descriptionLabel={{i18n "admin.discord_events.dashboard.description"}}
      >
        <:actions as |actions|>
          <actions.Default
            @action={{this.testConnection}}
            @icon="plug"
            @label="admin.discord_events.dashboard.test_connection"
            @isLoading={{this.busy}}
            class="discord-events-admin__test-connection"
          />
          <actions.Primary
            @action={{this.syncNow}}
            @icon="arrows-rotate"
            @label="admin.discord_events.dashboard.sync_now"
            @isLoading={{this.busy}}
            class="discord-events-admin__sync-now"
          />
          <actions.Danger
            @action={{this.clearCache}}
            @icon="trash-can"
            @label="admin.discord_events.dashboard.clear_cache"
            class="discord-events-admin__clear-cache"
          />
        </:actions>
      </DPageSubheader>

      {{#if this.connectionResult}}
        <div
          class="discord-events-admin__connection-result
            {{if this.connectionResult.ok '-success' '-error'}}"
          role="status"
        >
          {{dIcon (if this.connectionResult.ok "check" "xmark")}}
          {{this.connectionResult.message}}
        </div>
      {{/if}}

      <AdminConfigAreaCard
        @heading="admin.discord_events.dashboard.status_heading"
        class="discord-events-admin__status"
      >
        <:content>
          <ul class="discord-events-admin__checks">
            {{#each this.statusRows as |row|}}
              <li class={{if row.ok "-ok" "-off"}}>
                {{dIcon (if row.ok "check" "xmark")}}
                {{row.label}}
              </li>
            {{/each}}
          </ul>

          <dl class="discord-events-admin__facts">
            <dt>{{i18n "admin.discord_events.dashboard.cached_events"}}</dt>
            <dd>{{this.status.cached_event_count}}
              ({{i18n
                "admin.discord_events.dashboard.upcoming_count"
                count=this.status.upcoming_event_count
              }},
              {{i18n
                "admin.discord_events.dashboard.past_count"
                count=this.status.past_event_count
              }})</dd>

            <dt>{{i18n "admin.discord_events.dashboard.last_sync"}}</dt>
            <dd>
              {{#if this.status.last_completed_at}}
                {{dFormatDate this.status.last_completed_at leaveAgo="true"}}
                {{#if this.lastDuration}}({{this.lastDuration}}){{/if}}
              {{else}}
                {{i18n "admin.discord_events.dashboard.never"}}
              {{/if}}
            </dd>

            <dt>{{i18n "admin.discord_events.dashboard.next_sync"}}</dt>
            <dd>
              {{#if this.status.next_sync_at}}
                {{dFormatDate this.status.next_sync_at leaveAgo="true"}}
              {{else}}
                {{i18n "admin.discord_events.dashboard.not_scheduled"}}
              {{/if}}
            </dd>

            <dt>{{i18n "admin.discord_events.dashboard.api_status"}}</dt>
            <dd>
              {{#if this.status.rate_limited}}
                {{i18n "admin.discord_events.dashboard.rate_limited"}}
              {{else if this.lastError}}
                {{i18n "admin.discord_events.dashboard.api_error"}}
              {{else}}
                {{i18n "admin.discord_events.dashboard.api_ok"}}
              {{/if}}
            </dd>
          </dl>

          {{#if this.lastError}}
            <div class="discord-events-admin__last-error" role="alert">
              <strong>{{i18n
                  "admin.discord_events.dashboard.last_error"
                }}</strong>
              <code>{{this.lastError.error_class}}</code>
              {{this.lastError.message}}
              ({{dFormatDate this.lastError.at leaveAgo="true"}})
            </div>
          {{/if}}
        </:content>
      </AdminConfigAreaCard>

      <AdminConfigAreaCard
        @heading="admin.discord_events.dashboard.history_heading"
        class="discord-events-admin__history"
      >
        <:content>
          {{#if this.status.history.length}}
            <table class="d-table">
              <thead class="d-table__header">
                <tr class="d-table__row">
                  <th class="d-table__header-cell">{{i18n
                      "admin.discord_events.dashboard.history_when"
                    }}</th>
                  <th class="d-table__header-cell">{{i18n
                      "admin.discord_events.dashboard.history_result"
                    }}</th>
                  <th class="d-table__header-cell">{{i18n
                      "admin.discord_events.dashboard.history_details"
                    }}</th>
                </tr>
              </thead>
              <tbody class="d-table__body">
                {{#each this.status.history as |entry|}}
                  <tr class="d-table__row">
                    <td class="d-table__cell">{{dFormatDate
                        entry.at
                        leaveAgo="true"
                      }}</td>
                    <td class="d-table__cell">
                      {{#if entry.success}}
                        {{dIcon "check"}}
                        {{i18n
                          "admin.discord_events.dashboard.history_success"
                        }}
                      {{else}}
                        {{dIcon "xmark"}}
                        {{i18n
                          "admin.discord_events.dashboard.history_failure"
                        }}
                      {{/if}}
                    </td>
                    <td class="d-table__cell">
                      {{#if entry.success}}
                        {{i18n
                          "admin.discord_events.dashboard.history_summary"
                          created=entry.created
                          updated=entry.updated
                          deleted=entry.deleted
                          completed=entry.completed
                        }}
                      {{else}}
                        {{entry.message}}
                      {{/if}}
                    </td>
                  </tr>
                {{/each}}
              </tbody>
            </table>
          {{else}}
            <p>{{i18n "admin.discord_events.dashboard.history_empty"}}</p>
          {{/if}}
        </:content>
      </AdminConfigAreaCard>
    </div>
  </template>
}
