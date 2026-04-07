# Roles:
# - Superuser (full admin)
# - Dig director (admin for particular dig)
# - Field director (editor for particular dig)
# - Square supervisor (editor for particular square)
# - Lab supervisor (editor for particular lab)
# - Viewer (same as unregistered user, but with an account)
#
# Keep in mind that this is an ActiveModel object rather than ActiveRecord,
# so we have to do object management and mapping ourselves.
# Usage:
#
#     user = User.from_omniauth(auth_hash)
#     user.save # => (saves to CouchDB) true if valid, false if not
#     user.valid? # => true/false based on validations
#     user.errors.full_messages # => array of validation error messages if any
class User < ApplicationRecord

  class << self
    @collection_name = 'opendig/users'
    attr_reader :collection_name

    def from_omniauth(auth)
      new(
        provider: auth.provider,
        uid: auth.uid,
        email: auth.info.email,
        name: auth.info.name
      )
    end

    def from_document(doc)
      # Rewrite attributes to match User's attribute structure
      { '_id' => :uid }.each { |couchdb_attr, attr| doc[attr] = doc.delete(couchdb_attr) }
      ['_rev'].each { |attr| doc.delete(attr) }

      user = new(doc)
      user.instance_variable_set(:@new_record, false) # Came from CouchDB, so not a new record
      user
    end

    def roles = %w[viewer lab_supervisor square_supervisor field_director dig_director superuser]

    def id_fields = %w[provider uid email]

    def where(**options)
      rows = []
      Rails.application.config.couchdb.view(collection_name, { keys: [options], reduce: false })['rows'].map do |row|
        rows << new(row['value'])
      end
      rows.map { |row| from_document(row.to_document) }
    end

    def find_by(**options)
      where(**options).first
    end

    def find_or_create_by(**options)
      find_by(**options) || new(options)
    end
  end

  attr_accessor :provider, :uid, :email, :name, :role, :role_access

  validates :provider, presence: true
  validates :uid, presence: true, uniqueness: { scope: :provider }
  validates :email, presence: true
  validates :name, presence: true
  validates :role, presence: true, inclusion: { in: User.roles }

  # Object shape in CouchDB:
  # {
  #   _id: <uid>, # str
  #   provider: <provider>, # str
  #   email: <email>, # str
  #   name: <name>, # str
  #   role: <role>, # str, one of User.roles
  #   role_access: [
  #     <id> # str, id of dig/square/lab the user has access to, depending on role
  #   ]
  # }
  def to_document(**options)
    doc = as_json(**options.deep_merge({ only: [:provider, :uid, :email, :name, :role, :role_access], root: true }))
    # Rewrite attributes to match CouchDB document structure
    { uid: '_id' }.each { |attr, couchdb_attr| doc[couchdb_attr] = doc.delete(attr.to_s) }

    doc
  end

  def initialize(attributes = {})
    super
    @role ||= "viewer"
    @role_access ||= []
    @new_record = true # Not persisted to CouchDB yet
    save!
  end

  def save!
    validate!

    response = Rails.application.config.couchdb.save_doc(to_document)
    if response['ok']
      @new_record = false
      synchronize!
      true
    else
      errors.add(:base, "Failed to save user: #{response['error']}")
      raise NotSaved, "Failed to save user: #{response['error']}"
    end
  end

  # Sync with CouchDB--update this object so that it's in line with CouchDB.
  def synchronize!
    updated_record = self.class.find_by(as_json(only: self.class.id_fields))
    replace updated_record
    @new_record = false
    validate!
  end

  def replace(other)
    [:uid, :provider, :email, :name, :role, :role_access].each do |field|
      send(:"#{field}=", other.send(field))
    end
  end

  def save
    save!
  rescue NotSaved, ActiveModel::ValidationError
    false
  end

  def ==(other)
    return false unless other.is_a? User

    as_json(only: self.class.id_fields) == other.as_json(only: self.class.id_fields)
  end

  def role_at_least?(role)
    role_before_type_cast >= User.roles[role]
  end

  def new_record? = @new_record

  class NotSaved < StandardError; end
end
