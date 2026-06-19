require 'rails_helper'

RSpec.describe User, type: :model do
  let(:users) { load_user_fixtures }

  context "when a new user is created" do
    it "is valid with valid attributes" do
      user = described_class.new(uid: "12345", provider: "test_provider", email: "test@example.com", name: "Test User", roles: { 'opendig' => ['viewer'] }, persist: false)
      expect(user).to be_valid
    end

    it "is not valid without a uid" do
      user = described_class.new(provider: "test_provider", email: "test@example.com", name: "Test User", roles: { 'opendig' => ['viewer'] }, persist: false)
      expect(user).not_to be_valid
    end

    it "is not valid without a provider" do
      user = described_class.new(uid: "12345", email: "test@example.com", name: "Test User", roles: { 'opendig' => ['viewer'] }, persist: false)
      expect(user).not_to be_valid
    end

    it "is not valid without an email" do
      user = described_class.new(uid: "12345", provider: "test_provider", name: "Test User", roles: { 'opendig' => ['viewer'] }, persist: false)
      expect(user).not_to be_valid
    end

    it "is not valid without a name" do
      user = described_class.new(uid: "12345", provider: "test_provider", email: "test@example.com", roles: { 'opendig' => ['viewer'] }, persist: false)
      expect(user).not_to be_valid
    end

    it "is not valid with an invalid role structure" do
      user = described_class.new(uid: "12345", provider: "test_provider", email: "test@example.com", name: "Test User", roles: { 'opendig' => 'viewer' }, persist: false)
      expect(user).not_to be_valid
      user = described_class.new(uid: "12345", provider: "test_provider", email: "test@example.com", name: "Test User", roles: { 'opendig' => ['invalid_role'] }, persist: false)
      expect(user).not_to be_valid
    end

    it "is valid even without an entry for the current project (defaults to viewer there)" do
      user = described_class.new(uid: "12345", provider: "test_provider", email: "test@example.com", name: "Test User", roles: { 'otherdig' => ['dig_director'] }, persist: false)
      expect(user).to be_valid
      expect(user.role).to eq('viewer') # current project is "opendig"
    end

    it "loads default role if none provided" do
      user = described_class.new(uid: "12345", provider: "test_provider", email: "test@example.com", name: "Test User", persist: false)
      expect(user.roles).to eq({ 'opendig' => [described_class.default_role] })
    end

    it "loads the original user when attempting to create a duplicate user" do
      original_user = described_class.new(uid: "12345", provider: "test_provider", email: "test@example.com", name: "Test User", persist: true)

      duplicate_user = described_class.new(uid: "12345", provider: "test_provider", email: "test2@example.com", name: "Test User 2", persist: true)

      expect(duplicate_user).to eq(original_user)
    end

    it "saves successfully with valid attributes" do
      user = described_class.new(uid: "12345", provider: "test_provider", email: "test@example.com", name: "Test User", roles: { 'opendig' => ['viewer'] }, persist: false)
      expect(user).to be_valid
      expect(user.save!).to be_truthy
    end

    it "errors when trying to save with invalid attributes" do
      allow(CouchDB.auth_db).to receive(:save_doc).and_return({ 'ok' => true })

      user = described_class.new(provider: "test_provider", email: "test@example.com", name: "Test User", persist: false)
      expect(user).not_to be_valid
      expect { user.save! }.to raise_error(ActiveModel::ValidationError)
    end
  end

  describe ".from_omniauth" do
    it "creates a new user when one does not exist" do
      allow(CouchDB.auth_db).to receive(:save_doc).and_return({ 'ok' => true })
      auth_data = { provider: "test_provider", uid: "12345", info: { email: "test@example.com", name: "Test User" } }
      user = described_class.from_omniauth(auth_data)

      expect(user).to be_a(described_class)
      expect(user.uid).to eq("12345")
      expect(user.provider).to eq("test_provider")
      expect(user.email).to eq("test@example.com")
      expect(user.name).to eq("Test User")
    end

    it "finds and returns an existing user" do
      existing_user = described_class.new(uid: "12345", provider: "test_provider", email: "test@example.com", name: "Test User", persist: true)
      auth_data = { provider: "test_provider", uid: "12345", info: { email: "test@example.com", name: "Test User" } }
      user = described_class.from_omniauth(auth_data)

      expect(user).to eq(existing_user)
    end
  end

  describe ".from_document" do
    it "creates a new user from a document" do
      doc = { "_id" => "12345", "uid" => "12345", "provider" => "test_provider", "email" => "test@example.com", "name" => "Test User" }
      user = described_class.from_document(doc)

      expect(user).to be_a(described_class)
      expect(user).to be_valid
      expect(user.uid).to eq("12345")
      expect(user.provider).to eq("test_provider")
      expect(user.email).to eq("test@example.com")
      expect(user.name).to eq("Test User")
    end
  end

  describe ".where" do
    it "returns users matching the given conditions" do
      described_class.new(uid: "12345", provider: "test", email: "test@example.com", name: "Test User")
      described_class.new(uid: "67890", provider: "test", email: "test2@example.com", name: "Test User 2")
      users_ = described_class.where(provider: "test")
      expect(users_.length).to eq(2)
    end

    it "returns an empty array when no users match the given conditions" do
      users_ = described_class.where(provider: "nonexistent_provider")
      expect(users_).to be_empty
    end
  end

  describe ".find" do
    it "finds a user by provider and uid" do
      user = described_class.new(uid: "12345", provider: "test_provider", email: "test@example.com", name: "Test User")
      found_user = described_class.find("test_provider__12345")
      expect(found_user).to eq(user)
    end

    it "finds a user by a hash of attributes" do
      user = described_class.new(uid: "12345", provider: "test_provider", email: "test@example.com", name: "Test User")
      found_user = described_class.find({ "provider" => "test_provider", "uid" => "12345" })
      expect(found_user).to eq(user)
    end
  end

  describe "#id" do
    it "returns a hash with provider and uid" do
      user = described_class.new(uid: "12345", provider: "test_provider", email: "test@example.com", name: "Test User", persist: false)
      expect(user.id).to eq({ "provider" => "test_provider", "uid" => "12345" })
    end
  end

  describe "#save!" do
    it "saves the user to the database" do
      user = described_class.new(uid: "unique_uid", provider: "test_provider", email: "test@example.com", name: "Test User", persist: false)
      expect { user.save! }.to change { described_class.find_all.size }.by(1)
      expect(user.save!).to be_truthy
    end

    it "does not save the user if it is invalid" do
      user = described_class.new(provider: "test_provider", uid: "12345", persist: false)
      expect(user).not_to be_valid
      expect { user.save! }.to raise_error(ActiveModel::ValidationError).and(not_change { described_class.find_all.size })
    end
  end

  describe "#synchronize!" do
    it "updates the user to match the database record" do
      user = described_class.new(uid: users[:viewer].uid, provider: users[:viewer].provider, email: "test@example.com", name: "Test User", persist: false)
      expect(user.synchronize!).to be_truthy
      expect(user.email).to eq(users[:viewer].email)
      expect(user.name).to eq(users[:viewer].name)
      expect(user).to eq(users[:viewer])
    end
  end

  describe "#role" do
    it "returns the user's role for the current dig" do
      user = described_class.new(uid: "12345", provider: "test_provider", email: "test@example.com", name: "Test User", roles: { "opendig" => ["viewer"] }, persist: false)
      expect(user.role).to eq("viewer")
    end
  end

  describe "#role_scopes" do
    it "returns the scopes for the user's role in the current dig" do
      user = described_class.new(uid: "12345", provider: "test_provider", email: "test@example.com", name: "Test User", roles: { "opendig" => %w[viewer scope1 scope2] }, persist: false)
      expect(user.role_scopes).to eq(%w[scope1 scope2])
    end
  end

  describe "role predicates and capabilities" do
    it "#superuser? is global across projects" do
      user = described_class.new(uid: "1", provider: "p", email: "e@e.com", name: "N", roles: { 'otherdig' => ['superuser'] }, persist: false)
      user.current_dig = 'opendig' # not a member of opendig at all
      expect(user).to be_superuser
      expect(user.can_manage_roles?).to be(true)
      expect(user.can_edit_registrar?).to be(true)
      expect(user.can_edit_dig_data?(area: '9', square: '9')).to be(true)
    end

    it "registrar can edit the registrar but not excavation data" do
      registrar = users[:registrar]
      expect(registrar.can_edit_registrar?).to be(true)
      expect(registrar.can_view_registrar?).to be(true)
      expect(registrar.can_edit_dig_data?(area: '1', square: '1')).to be(false)
      expect(registrar.can_manage_roles?).to be(false)
    end

    it "supervisors get registrar read-only and scoped dig-data edit" do
      area_sup = users[:area_supervisor]   # scope: area "1"
      square_sup = users[:square_supervisor] # scope: square ["1", "1"]

      expect(area_sup.can_view_registrar?).to be(true)
      expect(area_sup.can_edit_registrar?).to be(false)
      expect(area_sup.can_edit_dig_data?(area: '1', square: '5')).to be(true)
      expect(area_sup.can_edit_dig_data?(area: '2')).to be(false)

      expect(square_sup.can_edit_registrar?).to be(false)
      expect(square_sup.can_edit_dig_data?(area: '1', square: '1')).to be(true)
      expect(square_sup.can_edit_dig_data?(area: '1', square: '2')).to be(false)
    end

    it "viewers have no registrar access and cannot edit" do
      viewer = users[:viewer]
      expect(viewer.can_view_registrar?).to be(false)
      expect(viewer.can_edit_dig_data?(area: '1', square: '1')).to be(false)
    end

    it "dig directors can manage roles but not assign superuser" do
      dd = users[:dig_director]
      expect(dd.can_manage_roles?).to be(true)
      expect(dd.can_assign_role?('registrar')).to be(true)
      expect(dd.can_assign_role?('superuser')).to be(false)
      expect(users[:superuser].can_assign_role?('superuser')).to be(true)
    end
  end

  describe "email/password accounts" do
    after do
      doc = CouchDB.auth_db.get('email__pw@example.com') rescue nil
      CouchDB.auth_db.delete_doc(doc) if doc
    end

    it "registers an email user and authenticates the password" do
      user = described_class.register(email: 'PW@Example.com', password: 'supersecret', name: 'PW User')

      expect(user.provider).to eq('email')
      expect(user.uid).to eq('pw@example.com') # normalized
      expect(user.password_digest).to be_present
      expect(user).to be_valid
      expect(user.save).to be_truthy

      expect(described_class.authenticate_email('pw@example.com', 'supersecret')).to be_truthy
      expect(described_class.authenticate_email('PW@Example.com', 'supersecret')).to be_truthy # case-insensitive
      expect(described_class.authenticate_email('pw@example.com', 'wrong')).to be_nil
      expect(described_class.authenticate_email('nobody@example.com', 'supersecret')).to be_nil
    end

    it "requires a password of at least 8 characters" do
      user = described_class.register(email: 'pw@example.com', password: 'short', name: 'PW')
      expect(user).not_to be_valid
      expect(user.errors[:password].join).to match(/8 characters/)
    end

    it "requires a matching confirmation when one is given" do
      user = described_class.register(email: 'pw@example.com', password: 'supersecret', password_confirmation: 'different', name: 'PW')
      expect(user).not_to be_valid
    end
  end

  describe "#apply_pending_invitations!" do
    let(:user) { described_class.new(uid: 'invitee-uid', provider: 'test_provider', email: 'invitee@example.com', name: 'Invitee') }

    after { Invitation.find('opendig', 'invitee@example.com')&.revoke! }

    it "applies a pending invitation to the user's roles and marks it accepted" do
      Invitation.new(email: 'invitee@example.com', project: 'opendig', role: 'registrar', invited_by: 'a@example.com').save!

      user.apply_pending_invitations!
      user.current_dig = 'opendig'

      expect(user.role).to eq('registrar')
      expect(Invitation.pending_for('invitee@example.com')).to be_empty
    end

    it "is a no-op when there are no pending invitations" do
      expect(user.apply_pending_invitations!).to eq([])
    end
  end

  describe "#role_at_least?" do
    it "returns true if user's role is equal to the given role" do
      expect(users[:viewer]).to be_role_at_least(:viewer)
      expect(users[:square_supervisor]).to be_role_at_least(:square_supervisor)
      expect(users[:superuser]).to be_role_at_least(:superuser)
    end

    it "returns true if user's role is higher than the given role" do
      expect(users[:square_supervisor]).to be_role_at_least(:viewer)
      expect(users[:superuser]).to be_role_at_least(:viewer)
      expect(users[:superuser]).to be_role_at_least(:square_supervisor)
    end

    it "returns false if user's role is lower than the given role" do
      expect(users[:viewer]).not_to be_role_at_least(:square_supervisor)
      expect(users[:viewer]).not_to be_role_at_least(:superuser)
      expect(users[:square_supervisor]).not_to be_role_at_least(:superuser)
    end
  end
end

