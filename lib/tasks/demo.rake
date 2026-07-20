namespace :demo do
  desc "Remove visitor accounts from the demo database (keeps @demo.example.com accounts). Runs on Sundays only when scheduled daily; set FORCE_CLEANUP=1 to run immediately."
  task cleanup_visitors: :environment do
    if ENV["FORCE_CLEANUP"] || Time.current.sunday?
      load Rails.root.join("db/scripts/cleanup_demo_visitors.rb")
    else
      puts "Skipping cleanup (not Sunday). Set FORCE_CLEANUP=1 to run immediately."
    end
  end
end
