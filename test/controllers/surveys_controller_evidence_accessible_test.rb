# frozen_string_literal: true

require "test_helper"
require "net/http"

class SurveysControllerEvidenceAccessibleTest < ActiveSupport::TestCase
  class FakeHttp
    attr_accessor :use_ssl, :open_timeout, :read_timeout

    def initialize(responses)
      @responses = Array(responses)
    end

    def request(_req)
      @responses.shift || raise("No more fake responses")
    end
  end

  setup do
    @controller = SurveysController.new
  end

  test "evidence_accessible? returns invalid for malformed urls" do
    assert_equal [ false, :invalid ], @controller.send(:evidence_accessible?, "://not a url")
  end

  test "evidence_accessible? returns invalid for non-https urls" do
    assert_equal [ false, :invalid ], @controller.send(:evidence_accessible?, "http://drive.google.com/file/d/abc")
  end

  test "evidence_accessible? returns invalid for non-google hosts" do
    assert_equal [ false, :invalid ], @controller.send(:evidence_accessible?, "https://example.com/file")
  end

  test "evidence_accessible? returns ok for docs export endpoint success" do
    export_success = https_success("hello")

    http_queue = [
      FakeHttp.new([ export_success ])
    ]

    Net::HTTP.stub(:new, ->(_host, _port) { http_queue.shift || FakeHttp.new([]) }) do
      assert_equal [ true, :ok ], @controller.send(:evidence_accessible?, "https://docs.google.com/document/d/abc123/edit")
    end
  end

  test "evidence_accessible? falls back after docs export forbidden and returns ok on generic head" do
    export_forbidden = Net::HTTPForbidden.new("1.1", "403", "Forbidden")
    head_success = https_success

    http_queue = [
      FakeHttp.new([ export_forbidden ]),
      FakeHttp.new([ head_success ])
    ]

    Net::HTTP.stub(:new, ->(_host, _port) { http_queue.shift || FakeHttp.new([]) }) do
      assert_equal [ true, :ok ], @controller.send(:evidence_accessible?, "https://docs.google.com/document/d/abc123/edit")
    end
  end

  test "evidence_accessible? returns forbidden when sniff body indicates access is required" do
    head_success = https_success
    sniff_success = https_success("You need access")

    http_queue = [
      FakeHttp.new([ head_success ]),
      FakeHttp.new([ sniff_success ])
    ]

    Net::HTTP.stub(:new, ->(_host, _port) { http_queue.shift || FakeHttp.new([]) }) do
      assert_equal [ false, :forbidden ], @controller.send(:evidence_accessible?, "https://drive.google.com/file/d/abc")
    end
  end

  test "evidence_accessible? blocks redirects to non-allowlisted hosts" do
    redirect = Net::HTTPFound.new("1.1", "302", "Found")
    redirect["location"] = "https://evil.example.com/login"

    http_queue = [ FakeHttp.new([ redirect ]) ]

    Net::HTTP.stub(:new, ->(_host, _port) { http_queue.shift || FakeHttp.new([]) }) do
      assert_equal [ false, :forbidden ], @controller.send(:evidence_accessible?, "https://drive.google.com/file/d/abc")
    end
  end

  test "evidence_accessible? returns too_many_redirects after repeated allowlisted redirects" do
    r1 = Net::HTTPFound.new("1.1", "302", "Found")
    r1["location"] = "https://drive.google.com/file/d/1"

    r2 = Net::HTTPFound.new("1.1", "302", "Found")
    r2["location"] = "https://drive.google.com/file/d/2"

    r3 = Net::HTTPFound.new("1.1", "302", "Found")
    r3["location"] = "https://drive.google.com/file/d/3"

    r4 = Net::HTTPFound.new("1.1", "302", "Found")
    r4["location"] = "https://drive.google.com/file/d/4"

    http_queue = [
      FakeHttp.new([ r1 ]),
      FakeHttp.new([ r2 ]),
      FakeHttp.new([ r3 ]),
      FakeHttp.new([ r4 ])
    ]

    Net::HTTP.stub(:new, ->(_host, _port) { http_queue.shift || FakeHttp.new([]) }) do
      assert_equal [ false, :too_many_redirects ], @controller.send(:evidence_accessible?, "https://drive.google.com/file/d/abc")
    end
  end

  test "evidence_accessible? falls back to GET when HEAD is not allowed" do
    head_not_allowed = Net::HTTPMethodNotAllowed.new("1.1", "405", "Method Not Allowed")
    get_success = https_success
    sniff_success = https_success("public")

    http_queue = [
      FakeHttp.new([ head_not_allowed, get_success ]),
      FakeHttp.new([ sniff_success ])
    ]

    Net::HTTP.stub(:new, ->(_host, _port) { http_queue.shift || FakeHttp.new([]) }) do
      assert_equal [ true, :ok ], @controller.send(:evidence_accessible?, "https://drive.google.com/file/d/abc")
    end
  end

  private

  def https_success(body = nil)
    resp = Net::HTTPSuccess.new("1.1", "200", "OK")
    resp.instance_variable_set(:@read, true)
    resp.instance_variable_set(:@body, body) if body
    resp
  end
end
