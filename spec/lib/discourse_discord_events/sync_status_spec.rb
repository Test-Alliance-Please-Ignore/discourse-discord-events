# frozen_string_literal: true

RSpec.describe DiscourseDiscordEvents::SyncStatus do
  before { enable_current_plugin }

  after { described_class.reset! }

  def successful_result(duration_ms: 120)
    result = DiscourseDiscordEvents::Discord::Synchronizer::Result.new
    result.created = 2
    result.updated = 1
    result.duration_ms = duration_ms
    result
  end

  it "starts empty" do
    expect(described_class.current).to eq({})
    expect(described_class.history).to eq([])
  end

  it "records the start of a run" do
    described_class.record_start

    expect(described_class.current["last_started_at"]).to be_present
  end

  it "records successful runs with metrics" do
    described_class.record_success(successful_result)

    status = described_class.current
    expect(status["last_success_at"]).to be_present
    expect(status["last_duration_ms"]).to eq(120)
    expect(status["last_error"]).to be_nil

    entry = described_class.history.first
    expect(entry["success"]).to eq(true)
    expect(entry["created"]).to eq(2)
    expect(entry["updated"]).to eq(1)
  end

  it "records failures without losing the last success timestamp" do
    described_class.record_success(successful_result)
    last_success = described_class.current["last_success_at"]

    described_class.record_failure(StandardError.new("boom"), 55)

    status = described_class.current
    expect(status["last_success_at"]).to eq(last_success)
    expect(status["last_error"]["message"]).to eq("boom")
    expect(status["last_error"]["error_class"]).to eq("StandardError")
    expect(status["last_duration_ms"]).to eq(55)
    expect(described_class.history.first["success"]).to eq(false)
  end

  it "clears the error after a subsequent success" do
    described_class.record_failure(StandardError.new("boom"), 55)
    described_class.record_success(successful_result)

    expect(described_class.current["last_error"]).to be_nil
  end

  it "caps the history length" do
    (described_class::HISTORY_LIMIT + 5).times do
      described_class.record_success(successful_result)
    end

    expect(described_class.history.size).to eq(described_class::HISTORY_LIMIT)
  end

  it "keeps the newest entries first" do
    described_class.record_failure(StandardError.new("older"), 1)
    described_class.record_success(successful_result)

    expect(described_class.history.first["success"]).to eq(true)
    expect(described_class.history.second["message"]).to eq("older")
  end
end
