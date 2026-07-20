DEMO_ADVISORS = [
  { email: "jordan.ellis@demo.example.com",  name: "Jordan Ellis" },
  { email: "morgan.hayes@demo.example.com",  name: "Morgan Hayes" },
  { email: "casey.rivera@demo.example.com",  name: "Casey Rivera" },
].freeze

DEMO_ADMINS = [
  { email: "avery.kim@demo.example.com",   name: "Avery Kim" },
  { email: "quinn.patel@demo.example.com", name: "Quinn Patel" },
].freeze

def upsert_demo_user(email:, name:, role:)
  user = User.find_or_initialize_by(email: email)
  user.assign_attributes(name: name, uid: email, role: role)
  user.save!(validate: false)
  user.send(:ensure_role_profile!)
  user.reload
end

puts "== Seeding Demo Advisors & Admins =="

puts "• Creating fake demo advisors"
demo_advisors = DEMO_ADVISORS.map { |a| upsert_demo_user(**a, role: "advisor") }

puts "• Reassigning all demo students to fake advisors (round-robin)"
count = 0
Student.find_each.with_index do |student, i|
  advisor = demo_advisors[i % demo_advisors.size]
  student.update_column(:advisor_id, advisor.advisor_profile.advisor_id)
  count += 1
end

puts "• Creating fake demo admin accounts"
DEMO_ADMINS.each { |a| upsert_demo_user(**a, role: "admin") }

puts ""
puts "Done."
puts "  Fake advisors created : #{demo_advisors.size}"
puts "  Fake admins created   : #{DEMO_ADMINS.size}"
puts "  Students reassigned   : #{count}"
puts ""
puts "Advisor breakdown:"
demo_advisors.each do |u|
  puts "  #{u.name} (#{u.email}) — #{u.advisor_profile.advisees.count} students"
end
