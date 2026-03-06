class User < ApplicationRecord
  enum role: { viewer: 0, editor: 1, admin: 2 }

  validates :uid, presence: true, uniqueness: { scope: :provider }
  validates :provider, presence: true
  validates :email, presence: true

  def role_at_least?(role)
    role_before_type_cast >= User.roles[role]
  end
end
