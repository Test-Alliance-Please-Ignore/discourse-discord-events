# frozen_string_literal: true

RSpec.describe DiscourseDiscordEvents::Discord::RateLimiter do
  subject(:limiter) { described_class.new }

  before { enable_current_plugin }
  after { limiter.reset! }

  it "is not blocked by default" do
    expect(limiter.blocked?).to eq(false)
    expect(limiter.wait_time).to eq(0)
  end

  describe "#record_rate_limit!" do
    it "blocks for the given duration" do
      limiter.record_rate_limit!(30)

      expect(limiter.blocked?).to eq(true)
      expect(limiter.wait_time).to be_within(2).of(30)
    end

    it "enforces a minimum block of one second" do
      limiter.record_rate_limit!(0)

      expect(limiter.blocked?).to eq(true)
    end
  end

  describe "#track_response_headers" do
    it "blocks when the bucket is exhausted" do
      limiter.track_response_headers("x-ratelimit-remaining" => "0", "x-ratelimit-reset-after" => "12.5")

      expect(limiter.blocked?).to eq(true)
      expect(limiter.wait_time).to be_within(2).of(12.5)
    end

    it "does nothing while requests remain in the bucket" do
      limiter.track_response_headers("x-ratelimit-remaining" => "3", "x-ratelimit-reset-after" => "12.5")

      expect(limiter.blocked?).to eq(false)
    end

    it "does nothing when headers are absent" do
      limiter.track_response_headers({})

      expect(limiter.blocked?).to eq(false)
    end
  end

  describe "#reset!" do
    it "clears the block" do
      limiter.record_rate_limit!(30)
      limiter.reset!

      expect(limiter.blocked?).to eq(false)
    end
  end
end
