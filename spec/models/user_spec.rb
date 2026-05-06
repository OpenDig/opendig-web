require 'rails_helper'

RSpec.describe User, type: :model do
  let(:users) { load_user_fixtures }

  context "when a new user is created" do
    it "is valid with valid attributes" do
      user = User.new(uid: "12345", provider: "test_provider", email: "test@example.com", name: "Test User", roles: { 'opendig' => ['viewer'] }, persist: false)
      expect(user).to be_valid
    end

    it "is not valid without a uid" do
      user = User.new(provider: "test_provider", email: "test@example.com", name: "Test User", roles: { 'opendig' => ['viewer'] }, persist: false)
      expect(user).to_not be_valid
    end

    it "is not valid without a provider" do
      user = User.new(uid: "12345", email: "test@example.com", name: "Test User", roles: { 'opendig' => ['viewer'] }, persist: false)
      expect(user).to_not be_valid
    end

    it "is not valid without an email" do
      user = User.new(uid: "12345", provider: "test_provider", name: "Test User", roles: { 'opendig' => ['viewer'] }, persist: false)
      expect(user).to_not be_valid
    end

    it "is not valid without a name" do
      user = User.new(uid: "12345", provider: "test_provider", email: "test@example.com", roles: { 'opendig' => ['viewer'] }, persist: false)
      expect(user).to_not be_valid
    end

    it "is not valid with an invalid role structure" do
      user = User.new(uid: "12345", provider: "test_provider", email: "test@example.com", name: "Test User", roles: { 'opendig' => 'viewer' }, persist: false)
      expect(user).to_not be_valid
      user = User.new(uid: "12345", provider: "test_provider", email: "test@example.com", name: "Test User", roles: { 'opendig' => ['invalid_role'] }, persist: false)
      expect(user).to_not be_valid
      user = User.new(uid: "12345", provider: "test_provider", email: "test@example.com", name: "Test User", roles: { 'otherdig' => ['viewer'] }, persist: false)
      expect(user).to_not be_valid
    end

    it "loads default role if none provided" do
      user = User.new(uid: "12345", provider: "test_provider", email: "test@example.com", name: "Test User", persist: false)
      expect(user.roles).to eq({ 'opendig' => [User.default_role] })
    end

    it "loads the original user when attempting to create a duplicate user" do
      original_user = User.new(uid: "12345", provider: "test_provider", email: "test@example.com", name: "Test User", persist: true)

      duplicate_user = User.new(uid: "12345", provider: "test_provider", email: "test2@example.com", name: "Test User 2", persist: true)

      expect(duplicate_user).to eq(original_user)
    end

    it "saves successfully with valid attributes" do
      user = User.new(uid: "12345", provider: "test_provider", email: "test@example.com", name: "Test User", roles: { 'opendig' => ['viewer'] }, persist: false)
      expect(user).to be_valid
      expect(user.save!).to be_truthy
    end

    it "errors when trying to save with invalid attributes" do
      allow(CouchDB.auth_db).to receive(:save_doc).and_return({ 'ok' => true })

      user = User.new(provider: "test_provider", email: "test@example.com", name: "Test User", persist: false)
      expect(user).to_not be_valid
      expect { user.save! }.to raise_error(ActiveModel::ValidationError)
    end
  end

  describe ".from_omniauth" do
    it "creates a new user when one does not exist" do
      allow(CouchDB.auth_db).to receive(:save_doc).and_return({ 'ok' => true })
      auth_data = {provider: "test_provider", uid: "12345", info: { email: "test@example.com", name: "Test User" }}
      user = User.from_omniauth(auth_data)

      expect(user).to be_a(User)
      expect(user.uid).to eq("12345")
      expect(user.provider).to eq("test_provider")
      expect(user.email).to eq("test@example.com")
      expect(user.name).to eq("Test User")
    end

    it "finds and returns an existing user" do
      existing_user = User.new(uid: "12345", provider: "test_provider", email: "test@example.com", name: "Test User", persist: true)
      auth_data = {provider: "test_provider", uid: "12345", info: { email: "test@example.com", name: "Test User" }}
      user = User.from_omniauth(auth_data)

      expect(user).to eq(existing_user)
    end
  end

  describe ".from_document" do
    it "creates a new user from a document" do
      doc = { "_id" => "12345", "uid" => "12345", "provider" => "test_provider", "email" => "test@example.com", "name" => "Test User" }
      user = User.from_document(doc)

      expect(user).to be_a(User)
      expect(user).to be_valid
      expect(user.uid).to eq("12345")
      expect(user.provider).to eq("test_provider")
      expect(user.email).to eq("test@example.com")
      expect(user.name).to eq("Test User")
    end
  end

  describe ".where" do
    it "returns users matching the given conditions" do
      User.new(uid: "12345", provider: "test", email: "test@example.com", name: "Test User")
      User.new(uid: "67890", provider: "test", email: "test2@example.com", name: "Test User 2")
      users_ = User.where(provider: "test")
      expect(users_.length).to eq(2)
    end

    it "returns an empty array when no users match the given conditions" do
      users_ = User.where(provider: "nonexistent_provider")
      expect(users_).to be_empty
    end
  end

  describe ".find" do
    it "finds a user by provider and uid" do
      user = User.new(uid: "12345", provider: "test_provider", email: "test@example.com", name: "Test User")
      found_user = User.find("test_provider__12345")
      expect(found_user).to eq(user)
    end
    it "finds a user by a hash of attributes" do
      user = User.new(uid: "12345", provider: "test_provider", email: "test@example.com", name: "Test User")
      found_user = User.find({ "provider" => "test_provider", "uid" => "12345" })
      expect(found_user).to eq(user)
    end
  end

  describe "#id" do
    it "returns a hash with provider and uid" do
      user = User.new(uid: "12345", provider: "test_provider", email: "test@example.com", name: "Test User", persist: false)
      expect(user.id).to eq({ "provider" => "test_provider", "uid" => "12345" })
    end
  end

  describe "#save!" do
    it "saves the user to the database" do
      user = User.new(uid: "unique_uid", provider: "test_provider", email: "test@example.com", name: "Test User", persist: false)
      expect { user.save! }.to change { User.find_all.size }.by(1)
      expect(user.save!).to be_truthy
    end

    it "does not save the user if it is invalid" do
      user = User.new(provider: "test_provider", uid: "12345", persist: false)
      expect(user).to_not be_valid
      expect { user.save! }.to raise_error(ActiveModel::ValidationError).and not_change { User.find_all.size }
    end
  end

  describe "#synchronize!" do
    it "updates the user to match the database record" do
      user = User.new(uid: users[:viewer].uid, provider: users[:viewer].provider, email: "test@example.com", name: "Test User", persist: false)
      expect(user.synchronize!).to be_truthy
      expect(user.email).to eq(users[:viewer].email)
      expect(user.name).to eq(users[:viewer].name)
      expect(user).to eq(users[:viewer])
    end
  end

  describe "#role" do
    it "returns the user's role for the current dig" do
      user = User.new(uid: "12345", provider: "test_provider", email: "test@example.com", name: "Test User", roles: { "opendig" => ["viewer"] }, persist: false)
      expect(user.role).to eq("viewer")
    end
  end

  describe "#role_scopes" do
    it "returns the scopes for the user's role in the current dig" do
      user = User.new(uid: "12345", provider: "test_provider", email: "test@example.com", name: "Test User", roles: { "opendig" => ["viewer", "scope1", "scope2"] }, persist: false)
      expect(user.role_scopes).to eq(["scope1", "scope2"])
    end
  end

  describe "#role_at_least?" do
    it "returns true if user's role is equal to the given role" do
      expect(users[:viewer].role_at_least?(:viewer)).to be_truthy
      expect(users[:square_supervisor].role_at_least?(:square_supervisor)).to be_truthy
      expect(users[:superuser].role_at_least?(:superuser)).to be_truthy
    end

    it "returns true if user's role is higher than the given role" do
      expect(users[:square_supervisor].role_at_least?(:viewer)).to be_truthy
      expect(users[:superuser].role_at_least?(:viewer)).to be_truthy
      expect(users[:superuser].role_at_least?(:square_supervisor)).to be_truthy
    end

    it "returns false if user's role is lower than the given role" do
      expect(users[:viewer].role_at_least?(:square_supervisor)).to be_falsey
      expect(users[:viewer].role_at_least?(:superuser)).to be_falsey
      expect(users[:square_supervisor].role_at_least?(:superuser)).to be_falsey
    end
  end
end

