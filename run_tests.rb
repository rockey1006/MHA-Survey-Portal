#!/usr/bin/env ruby

# Test runner script for Health Professions Rails application
# This script runs different test suites and provides comprehensive test reporting

require 'optparse'

class TestRunner
  def initialize
    @options = {}
    @test_types = %w[models controllers integration system all]
  end

  def parse_options
    OptionParser.new do |opts|
      opts.banner = "Usage: ruby run_tests.rb [options]"

      opts.on("-t", "--type TYPE", @test_types,
              "Select test type (#{@test_types.join(', ')})") do |type|
        @options[:type] = type
      end

      opts.on("-v", "--verbose", "Run tests with verbose output") do
        @options[:verbose] = true
      end

      opts.on("-c", "--coverage", "Generate coverage report") do
        @options[:coverage] = true
      end

      opts.on("-p", "--parallel", "Run tests in parallel") do
        @options[:parallel] = true
      end

      opts.on("-h", "--help", "Show this help message") do
        puts opts
        exit
      end
    end.parse!
  end

  def run
    parse_options

    puts "🧪 Health Professions Test Suite Runner"
    puts "=" * 50

    setup_environment
    run_tests
    generate_report
  end

  private

  def setup_environment
    puts "📋 Setting up test environment..."

    # Set test environment
    ENV['RAILS_ENV'] = 'test'

    # Set database connection parameters for Docker PostgreSQL if not already set
    # When running inside docker-compose the service provides correct PGHOST/PORT.
    ENV['PGHOST'] ||= 'localhost'
    ENV['PGPORT'] ||= '5433'
    ENV['PGUSER'] ||= 'dev_user'
    ENV['PGPASSWORD'] ||= 'dev_pass'

    puts "🔗 Database connection configured for Docker PostgreSQL (localhost:5433)"

    # Add coverage tracking if requested
    if @options[:coverage]
      puts "📊 Coverage tracking enabled"
      # Coverage will be started inside the test process (test/test_helper.rb).
      # Export a flag so the test process knows to start SimpleCov.
      ENV['COVERAGE'] = '1'
    end

    puts "✅ Environment ready"
  end

  def run_tests
    test_command = build_test_command

    puts "🚀 Running tests..."
    puts "Command: #{test_command}"
    puts "-" * 50

    success = system(test_command)

    if success
      puts "✅ All tests passed!"
    else
      puts "❌ Some tests failed. Check output above."
      exit(1)
    end
  end

  def build_test_command
    base_command = "rails test"

    # Add specific test paths based on type
    case @options[:type]
    when 'models'
      base_command += " test/models"
    when 'controllers'
      base_command += " test/controllers"
    when 'integration'
      base_command += " test/integration"
    when 'system'
      base_command += " test/system"
    when 'all', nil
         # Run all tests (default)
    end

    # Add verbose flag
    base_command += " --verbose" if @options[:verbose]

    base_command
  end

  def generate_report
    puts "\n📊 Test Report"
    puts "=" * 50

    # Test counts by type
    puts "📈 Test Statistics:"

    test_files = {
      'Models' => Dir['test/models/*_test.rb'].length,
      'Controllers' => Dir['test/controllers/*_test.rb'].length,
      'Integration' => Dir['test/integration/*_test.rb'].length,
      'System' => Dir['test/system/*_test.rb'].length
    }

    test_files.each do |type, count|
      puts "  #{type}: #{count} test files"
    end

    total_files = test_files.values.sum
    puts "  Total: #{total_files} test files"

    # Coverage report if enabled
    if @options[:coverage]
      puts "\n📊 Coverage report will be generated in coverage/ directory"
    end

    puts "\n🎉 Test run complete!"
    puts "💡 Tips:"
    puts "  - Run specific test types with -t option"
    puts "  - Enable coverage tracking with -c option"
    puts "  - Use -v for verbose output"
    puts "  - Run 'ruby run_tests.rb -h' for all options"
  end
end

# Run the test suite
if __FILE__ == $0
  TestRunner.new.run
end
