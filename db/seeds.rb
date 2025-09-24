# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Create admin user
Admin.find_or_create_by(email: 'rainsuds@tamu.edu') do |admin|
  admin.full_name = 'System Administrator'
  admin.role = 'admin'
  puts "Created admin user: #{admin.email}"
end
