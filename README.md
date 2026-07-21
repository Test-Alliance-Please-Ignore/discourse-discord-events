# discourse-discord-events

Displays **Discord Scheduled Events** from a Discord guild inside Discourse.

The plugin is strictly **read-only**: Discord remains the single source of
truth. It never creates, edits, deletes, or RSVPs to events — it only mirrors
them into a local cache and renders them.

## Features

- Periodic background synchronization of a guild's scheduled events (Sidekiq)
- Local cache — the event browser keeps working while Discord is down
- Public event browser at `/discord-events` with search, upcoming/past
  filters, sorting, and pagination
- Event detail pages with cover image, description, dates, location, host,
  and an "Open in Discord" button
- Optional "Events" item in the top navigation
- Admin dashboard with connection test, manual sync, cache clearing,
  synchronization metrics, and run history
- Respects Discourse permissions: on public sites anonymous visitors can
  browse; on login-required sites the usual authentication applies

## Installation

Follow the standard [plugin installation guide](https://meta.discourse.org/t/install-plugins-in-discourse/19157):

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/mcp/discourse-discord-events.git
```

Rebuild the container afterwards:

```sh
cd /var/discourse
./launcher rebuild app
```

## Discord setup

1. Create an application at <https://discord.com/developers/applications>
   and add a **Bot** to it.
2. Copy the **bot token** (Bot → Reset Token).
3. Invite the bot to your guild using an OAuth2 URL with:
   - **Scope:** `bot`
   - **Bot permission:** `View Channels` (`VIEW_CHANNEL`)

   No other permissions are required — the plugin only reads scheduled
   events via the REST API and never writes to Discord.
4. Enable **Developer Mode** in your Discord client (Settings → Advanced),
   right-click your server, and **Copy Server ID** — this is the guild ID.

The plugin uses Discord REST API **v10**
(`GET /guilds/{guild.id}/scheduled-events`).

## Configuration

All settings live under **Admin → Settings → Plugins → Discord Events**:

| Setting | Purpose |
| --- | --- |
| `discord_events_enabled` | Master switch for the plugin |
| `discord_events_sync_enabled` | Enables periodic background synchronization |
| `discord_events_bot_token` | Bot token (stored as a secret, never exposed to clients) |
| `discord_events_guild_id` | ID of the guild whose events are shown |
| `discord_events_sync_interval_minutes` | Cadence of the background sync (5–1440 minutes) |
| `discord_events_max_cached_events` | Cache cap; oldest finished events are pruned first |
| `discord_events_default_sort` | Default sort order of the event list |
| `discord_events_top_menu` | Adds an "Events" item to the top navigation |

After configuring, open **Admin → Plugins → Discord Events** and use
**Test connection** to verify the token and guild ID, then **Sync now** for
the initial import.

## Architecture

```
lib/discourse_discord_events/
  discord/client.rb          # Authenticated HTTP/JSON client (FinalDestination::HTTP)
  discord/scheduled_events.rb# Guild Scheduled Events endpoint wrapper
  discord/synchronizer.rb    # Idempotent mirror of API state into the cache
  discord/rate_limiter.rb    # Redis-backed cross-process rate limit state
  discord/errors.rb          # Typed error hierarchy
  sync_status.rb             # PluginStore-backed sync metrics + history
  admin_status.rb            # Aggregate for the admin dashboard

app/models/discourse_discord_events/event.rb   # Cached event (discourse_discord_events_events)
app/jobs/scheduled/.../schedule_sync.rb        # Every 5 min; enqueues when the interval elapsed
app/jobs/regular/.../sync_scheduled_events.rb  # One sync run with retry/backoff
app/controllers/...                            # Public events API + admin API
app/serializers/...                            # List / detail / admin status serializers
assets/javascripts/discourse/                  # Public Ember frontend (list, detail, nav)
admin/assets/javascripts/discourse/            # Admin dashboard frontend
```

All HTTP communication with Discord is confined to the `Discord::` layer.

### Synchronization process

1. `Jobs::DiscourseDiscordEvents::ScheduleSync` runs every 5 minutes and
   enqueues a sync when `discord_events_sync_interval_minutes` has elapsed
   (tracked in Redis, so multi-process deployments do not double-sync).
2. `Jobs::DiscourseDiscordEvents::SyncScheduledEvents` takes a distributed
   mutex and calls `Discord::Synchronizer`.
3. The synchronizer fetches all scheduled events for the guild and, inside a
   transaction, writes only actual changes:
   - new events are created, changed events updated (idempotent upserts)
   - Discord's API only returns *scheduled* and *active* events, so events
     that disappear from the response are either **marked completed** (they
     had already started) or **deleted** (they were canceled/removed before
     starting)
   - events cached for a previously configured guild are removed
   - the cache is pruned to `discord_events_max_cached_events`, oldest
     finished events first — upcoming events are never pruned
4. Metrics (duration, created/updated/deleted counts, errors) and a bounded
   run history are stored via `PluginStore` and shown on the admin dashboard.

Transient failures (network errors, Discord 5xx, rate limits) are retried
with exponential backoff up to 5 attempts. Configuration problems (bad
token, wrong guild ID, missing permissions) are not retried; they surface on
the admin dashboard instead. Regular users never see errors — they simply
keep browsing the cached events.

## Troubleshooting

| Symptom | Likely cause / fix |
| --- | --- |
| "Discord rejected the bot token" | Token is wrong or was reset — copy a fresh token from the developer portal |
| "The bot is not allowed to access this guild" | The bot was never invited to the guild, or lost `View Channels` |
| "Discord could not find this guild" | Guild ID is wrong — copy it again with Developer Mode enabled |
| "Rate limited" | Another burst of requests is in flight; the plugin backs off automatically |
| Events never appear | Check that both `discord_events_enabled` and `discord_events_sync_enabled` are on, then use **Sync now** and watch the history table |
| Stale events | Discord outages pause updates; the cache is served unchanged until the next successful sync |

Sync activity is logged with the `[discourse-discord-events]` prefix in
`/logs`.

## Development

```sh
cd ~/discourse/plugins
git clone <repo-url> discourse-discord-events
```

Backend tests (from the Discourse root):

```sh
bundle exec rspec plugins/discourse-discord-events/spec
```

Frontend tests (from the Discourse root):

```sh
bin/rails qunit:test MODULE="Discourse Discord Events"
# or open /qunit?qunit_skip_core=1 in a dev instance
```

Linting (from the plugin directory):

```sh
bundle exec rubocop
pnpm lint        # eslint, prettier, stylelint, glint
```

The test suite mocks all Discord API traffic with WebMock; no network access
or real bot token is needed.

## Upgrade notes

- The cache table is `discourse_discord_events_events`; migrations run
  automatically on rebuild.
- Clearing the cache (admin dashboard → **Clear cache**) is always safe: the
  next sync fully rebuilds it from Discord.
- If you change `discord_events_guild_id`, the next sync removes events of
  the old guild automatically.

## License

MIT — see [LICENSE](LICENSE).
