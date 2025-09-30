class Admin < ApplicationRecord
  devise :omniauthable, omniauth_providers: [ :google_oauth2 ]

  def self.from_google(email:, full_name:, uid:, avatar_url:, role: nil)
    # Use find_or_initialize_by to handle missing role column gracefully
    admin = find_or_initialize_by(email: email)

    # Update attributes for both new and existing records
    admin.uid = uid if admin.uid.blank?
    admin.full_name = full_name  # Always update full_name
    admin.avatar_url = avatar_url if admin.avatar_url.blank?

    # Always update role if provided and column exists
    if role.present? && admin.respond_to?(:role=)
      admin.role = role
    end

    admin.save! if admin.changed?
    admin
  end

  # Fallback method for role if column doesn't exist yet
  def role
    if self.class.column_names.include?("role")
      super
    else
      nil # Return nil if role column doesn't exist
    end
  end

  # Check if user is admin (has all advisor powers + role management)
  def admin?
    role == "admin"
  end

  # Check if user has advisor-level permissions (advisor or admin)
  def advisor?
    %w[advisor admin].include?(role)
  end

  # Check if user can manage roles (promote/demote advisors)
  def can_manage_roles?
    admin?
  end
end
