# Script to make rainsuds@tamu.edu an admin
# Run this in Rails console: rails console
# Then copy and paste these commands:

# Option A: Create admin account if it doesn't exist
admin = Admin.find_or_create_by(email: 'rainsuds@tamu.edu') do |a|
  a.full_name = 'Admin User'
  a.role = 'admin'
end

# Option B: Update existing account to admin
admin = Admin.find_by(email: 'rainsuds@tamu.edu')
if admin
  admin.update!(role: 'admin')
  puts "Updated #{admin.email} to admin role"
else
  puts "Account not found, creating new admin account"
  Admin.create!(
    email: 'rainsuds@tamu.edu',
    full_name: 'Admin User',
    role: 'admin'
  )
end

# Verify the change
admin = Admin.find_by(email: 'rainsuds@tamu.edu')
puts "Account: #{admin.email}, Role: #{admin.role}"