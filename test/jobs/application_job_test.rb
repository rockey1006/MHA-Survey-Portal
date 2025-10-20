require "test_helper"

class ApplicationJobTest < ActiveJob::TestCase
  class SampleJob < ApplicationJob
    self.queue_adapter = :inline

    def perform(value)
      value[:performed] = true
    end
  end

  test "job executes perform" do
    payload = {}
    SampleJob.perform_now(payload)
    assert payload[:performed]
  end
end
