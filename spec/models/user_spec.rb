require 'rails_helper'

RSpec.describe User, type: :model do
  fixtures :users

  it "is valid with valid attributes" do
    user = User.new(uid: "12345", provider: "test_provider", email: "test@example.com")
    expect(user).to be_valid
  end

  it "is not valid without a uid" do
    user = User.new(provider: "test_provider", email: "test@example.com")
    expect(user).to_not be_valid
  end

  it "is not valid without a provider" do
    user = User.new(uid: "12345", email: "test@example.com")
    expect(user).to_not be_valid
  end

  it "is not valid without an email" do
    user = User.new(uid: "12345", provider: "test_provider")
    expect(user).to_not be_valid
  end

  it "enforces uniqueness of uid scoped to provider" do
    User.create!(uid: "12345", provider: "test_provider", email: "test@example.com")
    duplicate_user = User.new(uid: "12345", provider: "test_provider", email: "test2@example.com")
    expect(duplicate_user).to_not be_valid
    other_provider_user = User.new(uid: "12345", provider: "other_provider", email: "test@example.com")
    expect(other_provider_user).to be_valid
  end

  # Specs for role_at_least? method
  describe "#role_at_least?" do
    it "returns true if user's role is equal to the given role" do
      expect(users(:viewer).role_at_least?(:viewer)).to be_truthy
      expect(users(:editor).role_at_least?(:editor)).to be_truthy
      expect(users(:admin).role_at_least?(:admin)).to be_truthy
    end

    it "returns true if user's role is higher than the given role" do
      expect(users(:editor).role_at_least?(:viewer)).to be_truthy
      expect(users(:admin).role_at_least?(:viewer)).to be_truthy
      expect(users(:admin).role_at_least?(:editor)).to be_truthy
    end

    it "returns false if user's role is lower than the given role" do
      expect(users(:viewer).role_at_least?(:editor)).to be_falsey
      expect(users(:viewer).role_at_least?(:admin)).to be_falsey
      expect(users(:editor).role_at_least?(:admin)).to be_falsey
    end
  end
end

