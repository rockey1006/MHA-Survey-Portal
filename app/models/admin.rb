# Persisted profile for users with administrative privileges.
# Provides convenience helpers for role checks and ensures the underlying user
# record stays in sync when admin-specific fields are saved.
class Admin < ApplicationRecord
  self.primary_key = :admin_id

  belongs_to :user, foreign_key: :admin_id, primary_key: :id, inverse_of: :admin_profile
  has_many :survey_change_logs, foreign_key: :admin_id, primary_key: :admin_id, inverse_of: :admin

  delegate :email, :email=, :name, :name=, :avatar_url, :avatar_url=, :uid, :uid=, :created_at, :updated_at, to: :user

  # @return [String] the admin's display name
  def full_name
    name
  end

  # @param value [String]
  # @return [void]
  def full_name=(value)
    self.name = value
  end

  # @return [String] the role assigned to the underlying user
  def role
    user.role
  end

  # @param value [String]
  # @return [void]
  def role=(value)
    user.role = value
  end

  # @return [Boolean] whether this profile represents a system administrator
  def admin?
    user.role_admin?
  end

  # @return [Boolean] whether the admin can view advisor features
  def advisor?
    user.role_advisor? || admin?
  end

  # @return [Boolean] whether the admin can assign or change user roles
  def can_manage_roles?
    admin?
  end

  # Persists the admin and any pending changes on the underlying user.
  #
  # @return [Boolean] true if the record saved successfully
  def save(*args, &block)
    user.save! if user&.changed?
    super
  end

  # Persists the admin and underlying user or raises on validation failure.
  #
  # @return [Boolean] true if the record saved successfully
  def save!(*args, &block)
    user.save! if user&.changed?
    super
  end
end
