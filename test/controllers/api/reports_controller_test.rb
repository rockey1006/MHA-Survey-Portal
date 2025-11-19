# frozen_string_literal: true

require "test_helper"

module Api
  class ReportsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @administrator = users(:admin)
    end

    test "should get benchmark data as administrator" do
      sign_in @administrator
      get api_reports_benchmark_url
      assert_response :success
      json_response = JSON.parse(response.body)
      assert_not_nil json_response["cards"]
    end
  end
end
