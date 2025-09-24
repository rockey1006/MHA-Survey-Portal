namespace :admin do
  desc "Make a user admin by email"
  task :create, [ :email ] => :environment do |task, args|
    email = args[:email]

    if email.blank?
      puts "Usage: rails admin:create[email@example.com]"
      exit 1
    end

    admin = Admin.find_or_create_by(email: email) do |a|
      a.full_name = "Admin User"
      a.role = "admin"
    end

    if admin.persisted?
      admin.update!(role: "admin") unless admin.role == "admin"
      puts "✅ Successfully made #{email} an admin"
      puts "Account details:"
      puts "  Email: #{admin.email}"
      puts "  Name: #{admin.full_name}"
      puts "  Role: #{admin.role}"
    else
      puts "❌ Failed to create admin account"
      puts admin.errors.full_messages
    end
  end

  desc "List all admin users"
  task list: :environment do
    admins = Admin.where(role: "admin")

    if admins.any?
      puts "\n📋 Admin Users:"
      puts "-" * 50
      admins.each do |admin|
        puts "#{admin.email} (#{admin.full_name || 'No name'})"
      end
      puts "-" * 50
      puts "Total: #{admins.count} admin(s)"
    else
      puts "No admin users found."
    end
  end

  desc "Create dummy student accounts for testing"
  task create_dummy_students: :environment do
    dummy_students = [
      { email: "student1@tamu.edu", full_name: "Emily Johnson", role: "student" },
      { email: "student2@tamu.edu", full_name: "Michael Chen", role: "student" },
      { email: "student3@tamu.edu", full_name: "Sarah Williams", role: "student" },
      { email: "student4@tamu.edu", full_name: "David Rodriguez", role: "student" },
      { email: "student5@tamu.edu", full_name: "Jessica Thompson", role: "student" }
    ]

    puts "\n🎓 Creating dummy student accounts..."
    puts "-" * 50

    created_count = 0
    dummy_students.each do |student_data|
      admin = Admin.find_or_create_by(email: student_data[:email]) do |a|
        a.full_name = student_data[:full_name]
        a.role = student_data[:role]
        # Generate fake avatar URL for testing
        a.avatar_url = "https://ui-avatars.com/api/?name=#{student_data[:full_name].gsub(' ', '+')}&background=500000&color=fff&size=128"
      end

      if admin.persisted?
        if admin.role != student_data[:role]
          admin.update!(role: student_data[:role])
        end
        puts "✅ #{admin.email} - #{admin.full_name} (#{admin.role})"
        created_count += 1
      else
        puts "❌ Failed to create #{student_data[:email]}"
        puts admin.errors.full_messages
      end
    end

    puts "-" * 50
    puts "✅ Created #{created_count} dummy student accounts"
    puts "\n📊 Current user counts:"
    puts "Students: #{Admin.where(role: 'student').count}"
    puts "Advisors: #{Admin.where(role: 'advisor').count}"
    puts "Admins: #{Admin.where(role: 'admin').count}"
    puts "Total Users: #{Admin.count}"
  end

  desc "Create dummy advisor accounts for testing"
  task create_dummy_advisors: :environment do
    dummy_advisors = [
      { email: "advisor1@tamu.edu", full_name: "Dr. Robert Smith", role: "advisor" },
      { email: "advisor2@tamu.edu", full_name: "Dr. Lisa Anderson", role: "advisor" },
      { email: "advisor3@tamu.edu", full_name: "Dr. James Wilson", role: "advisor" }
    ]

    puts "\n👨‍🏫 Creating dummy advisor accounts..."
    puts "-" * 50

    created_count = 0
    dummy_advisors.each do |advisor_data|
      admin = Admin.find_or_create_by(email: advisor_data[:email]) do |a|
        a.full_name = advisor_data[:full_name]
        a.role = advisor_data[:role]
        # Generate fake avatar URL for testing
        a.avatar_url = "https://ui-avatars.com/api/?name=#{advisor_data[:full_name].gsub(' ', '+')}&background=28a745&color=fff&size=128"
      end

      if admin.persisted?
        if admin.role != advisor_data[:role]
          admin.update!(role: advisor_data[:role])
        end
        puts "✅ #{admin.email} - #{admin.full_name} (#{admin.role})"
        created_count += 1
      else
        puts "❌ Failed to create #{advisor_data[:email]}"
        puts admin.errors.full_messages
      end
    end

    puts "-" * 50
    puts "✅ Created #{created_count} dummy advisor accounts"
    puts "\n📊 Current user counts:"
    puts "Students: #{Admin.where(role: 'student').count}"
    puts "Advisors: #{Admin.where(role: 'advisor').count}"
    puts "Admins: #{Admin.where(role: 'admin').count}"
    puts "Total Users: #{Admin.count}"
  end

  desc "Create all dummy accounts (students and advisors)"
  task create_all_dummies: [ :create_dummy_students, :create_dummy_advisors ] do
    puts "\n🎉 All dummy accounts created successfully!"
  end

  desc "Remove all dummy accounts"
  task cleanup_dummies: :environment do
    dummy_emails = [
      "student1@tamu.edu", "student2@tamu.edu", "student3@tamu.edu", "student4@tamu.edu", "student5@tamu.edu",
      "advisor1@tamu.edu", "advisor2@tamu.edu", "advisor3@tamu.edu"
    ]

    puts "\n🧹 Removing dummy accounts..."
    puts "-" * 50

    removed_count = 0
    dummy_emails.each do |email|
      admin = Admin.find_by(email: email)
      if admin
        admin.destroy!
        puts "🗑️ Removed #{email}"
        removed_count += 1
      else
        puts "⚠️ #{email} not found"
      end
    end

    puts "-" * 50
    puts "✅ Removed #{removed_count} dummy accounts"
    puts "\n📊 Remaining user counts:"
    puts "Students: #{Admin.where(role: 'student').count}"
    puts "Advisors: #{Admin.where(role: 'advisor').count}"
    puts "Admins: #{Admin.where(role: 'admin').count}"
    puts "Total Users: #{Admin.count}"
  end
end
