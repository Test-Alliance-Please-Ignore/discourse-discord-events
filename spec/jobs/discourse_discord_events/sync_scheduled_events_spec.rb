# frozen_string_literal: true

RSpec.describe Jobs::DiscourseDiscordEvents::SyncScheduledEvents do
  subject(:job) { described_class.new }

  let(:guild_id) { "987654321098765432" }
  let(:list_url) do
    "https://discord.com/api/v10/guilds/#{guild_id}/scheduled-events?with_user_count=true"
  end

  before do
    enable_current_plugin
    SiteSetting.discord_events_bot_token = "test-token"
    SiteSetting.discord_events_guild_id = guild_id
    Jobs.run_later!
  end

  after { DiscourseDiscordEvents::Discord::RateLimiter.new.reset! }

  it "synchronizes events" do
    stub_list_response(
      [
        {
          "id" => "111",
          "guild_id" => guild_id,
          "name" => "Movie Night",
          "status" => 1,
          "entity_type" => 3,
          "scheduled_start_time" => 2.days.from_now.iso8601,
        },
      ],
    )

    job.execute({})

    expect(DiscourseDiscordEvents::Event.where(discord_event_id: "111").count).to eq(1)
  end

  it "does nothing when the plugin is disabled" do
    SiteSetting.discord_events_enabled = false
    stub = stub_list_response([])

    job.execute({})

    expect(stub).not_to have_been_requested
  end

  it "retries with backoff on transient server errors" do
    stub_request(:get, list_url).to_return(status: 503, body: "")

    expect_enqueued_with(
      job: described_class,
      args: {
        attempt: 2,
      },
    ) { job.execute(attempt: 1) }
  end

  it "retries after the rate limit delay when rate limited" do
    stub_request(:get, list_url).to_return(
      status: 429,
      body: { "retry_after" => 60 }.to_json,
    )

    expect_enqueued_with(job: described_class, args: { attempt: 2 }) { job.execute(attempt: 1) }
  end

  it "gives up after the maximum number of attempts" do
    stub_request(:get, list_url).to_return(status: 503, body: "")

    expect_not_enqueued_with(job: described_class) do
      job.execute(attempt: described_class::MAX_ATTEMPTS)
    end
  end

  it "does not retry configuration problems" do
    SiteSetting.discord_events_guild_id = ""

    expect_not_enqueued_with(job: described_class) { job.execute({}) }
  end

  it "does not retry authentication failures" do
    stub_request(:get, list_url).to_return(status: 401, body: "{}")

    expect_not_enqueued_with(job: described_class) { job.execute({}) }

    expect(DiscourseDiscordEvents::SyncStatus.current["last_error"]["error_class"]).to eq(
      "DiscourseDiscordEvents::Discord::Errors::AuthenticationError",
    )
  end

  def stub_list_response(events)
    stub_request(:get, list_url).to_return(status: 200, body: events.to_json)
  end
end
