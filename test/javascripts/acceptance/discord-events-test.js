import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

const EVENT = {
  id: 1,
  name: "Movie Night",
  excerpt: "Bring popcorn",
  image_url: null,
  status: "scheduled",
  entity_type: "external",
  location: "The Lounge",
  external_url: null,
  participant_count: 12,
  scheduled_start_time: "2030-05-01T20:00:00Z",
  scheduled_end_time: "2030-05-01T22:00:00Z",
  discord_url: "https://discord.com/events/guild/event",
};

acceptance("Discord Events | event browser", function (needs) {
  needs.settings({
    discord_events_enabled: true,
    discord_events_default_sort: "start_time_asc",
  });

  needs.pretender((server, helper) => {
    server.get("/discord-events.json", () =>
      helper.response({
        events: [EVENT],
        meta: {
          page: 0,
          per_page: 24,
          total: 1,
          more: false,
          filter: "upcoming",
          sort: "start_time_asc",
        },
      })
    );

    server.get("/discord-events/1.json", () =>
      helper.response({
        event: {
          ...EVENT,
          description: "A very long description of the movie night.",
          creator_name: "Botty",
          synced_at: "2030-04-30T10:00:00Z",
        },
      })
    );
  });

  test("lists events and navigates to the detail page", async function (assert) {
    await visit("/discord-events");

    assert.dom(".discord-events__card").exists({ count: 1 });
    assert.dom(".discord-events__card-title").hasText("Movie Night");
    assert.dom(".discord-events__location").includesText("The Lounge");
    assert.dom(".discord-events__status-badge").hasText("Scheduled");
    assert
      .dom(".discord-events__pagination")
      .doesNotExist("pagination is hidden for a single page");

    await click(".discord-events__card-link");

    assert.dom(".discord-events__detail h1").hasText("Movie Night");
    assert
      .dom(".discord-events__description")
      .includesText("A very long description");
    assert
      .dom(".discord-events__discord-link")
      .hasAttribute("href", EVENT.discord_url);
  });
});

acceptance("Discord Events | empty state", function (needs) {
  needs.settings({ discord_events_enabled: true });

  needs.pretender((server, helper) => {
    server.get("/discord-events.json", () =>
      helper.response({
        events: [],
        meta: {
          page: 0,
          per_page: 24,
          total: 0,
          more: false,
          filter: "upcoming",
          sort: "start_time_asc",
        },
      })
    );
  });

  test("shows the empty message", async function (assert) {
    await visit("/discord-events");

    assert.dom(".discord-events__empty").exists();
    assert.dom(".discord-events__card").doesNotExist();
  });
});
