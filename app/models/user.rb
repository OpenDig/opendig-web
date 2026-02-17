class User < ApplicationRecord
  enum access_level: { viewer: 0, editor: 1, admin: 2 }

  validates :uid, presence: true, uniqueness: { scope: :provider }
  validates :provider, presence: true
  validates :email, presence: true
end
