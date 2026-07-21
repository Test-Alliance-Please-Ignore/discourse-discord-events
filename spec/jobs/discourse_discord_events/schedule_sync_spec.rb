# frozen_string_literal: true

RSpec.describe Jobs::DiscourseDiscordEvents::ScheduleSync do
  subject(:job) { described_class.new }

  before do
    enable_current_plugin
    SiteSetting.discord_events_sync_enabled = true
    Jobs.run_later!
  end

  it "enqueues a sync when due" do
    expect_enqueued_with(job: Jobs::DiscourseDiscordEvents::SyncScheduledEvents) { job.execute }
  end

  it "does not enqueue again inside the configured interval" do
    job.execute

    expect_not_enqueued_with(job: Jobs::DiscourseDiscordEvents::SyncScheduledEvents) do
      described_class.new.execute
    end
  end

  it "does nothing when the plugin is disabled" do
    SiteSetting.discord_events_enabled = false

    expect_not_enqueued_with(job: Jobs::DiscourseDiscordEvents::SyncScheduledEvents) do
      job.execute
    end
  end

  it "does nothing when synchronization is disabled" do
    SiteSetting.discord_events_sync_enabled = false

    expect_not_enqueued_with(job: Jobs::DiscourseDiscordEvents::SyncScheduledEvents) do
      job.execute
    end
  end
end
