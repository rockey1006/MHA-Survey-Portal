class User < ApplicationRecord
  self.primary_key = :id

  devise :omniauthable, omniauth_providers: [ :google_oauth2 ]

  enum :role, { student: "student", advisor: "advisor", admin: "admin" }, prefix: true

  has_one :admin_profile, class_name: "Admin", foreign_key: :admin_id, inverse_of: :user, dependent: :destroy
  has_one :advisor_profile, class_name: "Advisor", foreign_key: :advisor_id, inverse_of: :user, dependent: :destroy
  has_one :student_profile, class_name: "Student", foreign_key: :student_id, inverse_of: :user, dependent: :destroy
  has_many :notifications, as: :notifiable, dependent: :destroy

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
  validates :role, presence: true, inclusion: { in: roles.values }

  after_commit :ensure_role_profile!, on: [ :create, :update ]

  scope :students, -> { where(role: roles[:student]) }
  scope :advisors, -> { where(role: roles[:advisor]) }
  scope :admins, -> { where(role: roles[:admin]) }

  def self.from_google(email:, name:, uid:, avatar_url:, role: nil)
    user = find_or_initialize_by(email: email)
    user.uid = uid if uid.present?
    user.name = name if name.present?
    user.avatar_url = avatar_url if avatar_url.present?

    normalized_role = normalize_role(role) || user.role || roles[:student]
    user.role = normalized_role

    user.save!
    user.send(:ensure_role_profile!)
    user
  end

  def self.normalize_role(role)
    return nil if role.blank?

    role_string = role.to_s.downcase
    roles.find { |_key, value| value == role_string }&.last
  end

  def full_name
    name
  end

  def full_name=(value)
    self.name = value
  end

  private

  def ensure_role_profile!
    case role
    when self.class.roles[:admin]
      admin_profile || create_admin_profile!
    when self.class.roles[:advisor]
      advisor_profile || create_advisor_profile!
    when self.class.roles[:student]
      student_profile || create_student_profile!
    end
  end
end
