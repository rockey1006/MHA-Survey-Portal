class Admin < ApplicationRecord
  self.primary_key = :admin_id

  belongs_to :user, foreign_key: :admin_id, primary_key: :user_id, inverse_of: :admin_profile

  delegate :email, :email=, :name, :name=, :avatar_url, :avatar_url=, :uid, :uid=, :created_at, :updated_at, to: :user

  def full_name
    name
  end

  def full_name=(value)
    self.name = value
  end

  def role
    user.role
  end

  def role=(value)
    user.role = value
  end

  def admin?
    user.role_admin?
  end

  def advisor?
    user.role_advisor? || admin?
  end

  def can_manage_roles?
    admin?
  end

  def save(*args, &block)
    user.save! if user&.changed?
    super
  end

  def save!(*args, &block)
    user.save! if user&.changed?
    super
  end
end
