namespace :demo do
  desc "Remove visitor accounts from the demo database (keeps @demo.example.com accounts)"
  task cleanup_visitors: :environment do
    load Rails.root.join("db/scripts/cleanup_demo_visitors.rb")
  end
end
