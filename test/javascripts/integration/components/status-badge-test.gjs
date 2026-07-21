import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import StatusBadge from "discourse/plugins/discourse-discord-events/discourse/components/discord-events/status-badge";

module("Discourse Discord Events | Component | StatusBadge", function (hooks) {
  setupRenderingTest(hooks);

  test("renders the status label and modifier class", async function (assert) {
    await render(<template><StatusBadge @status="active" /></template>);

    assert.dom(".discord-events__status-badge").hasText("Happening now");
    assert.dom(".discord-events__status-badge").hasClass("-active");
  });

  test("renders canceled state", async function (assert) {
    await render(<template><StatusBadge @status="canceled" /></template>);

    assert.dom(".discord-events__status-badge").hasText("Canceled");
    assert.dom(".discord-events__status-badge").hasClass("-canceled");
  });
});
