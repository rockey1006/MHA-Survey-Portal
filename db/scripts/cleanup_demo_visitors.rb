puts "== Demo Visitor Cleanup =="

visitors = User.where.not("email LIKE ?", "%@demo.example.com")

if visitors.none?
  puts "No visitor accounts found. Nothing to do."
else
  puts "Found #{visitors.count} visitor account(s):"
  visitors.each { |u| puts "  [#{u.role}] #{u.name} <#{u.email}>" }
  puts ""

  # Safety check: skip any advisor visitor who somehow has demo students assigned.
  # This should never happen in normal operation, but guards against accidental
  # cascade-deleting demo student profiles.
  ids_to_skip = []
  visitors.select(&:role_advisor?).each do |u|
    if u.advisor_profile&.advisees&.exists?
      puts "SKIPPING #{u.email} — has advisees assigned; reassign students first"
      ids_to_skip << u.id
    end
  end

  to_delete = visitors.where.not(id: ids_to_skip)
  count = to_delete.count
  to_delete.destroy_all

  puts "Deleted #{count} visitor account(s)."
  puts "Skipped #{ids_to_skip.size} account(s) with advisees." if ids_to_skip.any?
end
