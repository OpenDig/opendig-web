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
#
# Usage:
#
#     user = User.from_omniauth(auth_hash)
#     user.save # => (saves to CouchDB) true if valid, false if not
#     user.valid? # => true/false based on validations
#     user.errors.full_messages # => array of validation error messages if any
#     [user.provider, user.uid, user.email, user.name, user.roles] # => access attributes
class User
  include ActiveModel::Model

  # Class methods
  class << self
    def collection_name
      'authdb/users'
    end

    def from_omniauth(auth)
      auth = auth.with_indifferent_access
      find_by(provider: auth[:provider], uid: auth[:uid]) ||
        new({
              provider: auth[:provider],
              uid: auth[:uid],
              email: auth[:info][:email],
              name: auth[:info][:name]
            })
    end

    def from_document(doc)
      new(doc.transform_keys(&:to_s).slice(*data_fields), persist: false)
    end

    # Roles are defined here in order of increasing permissions. The default role is taken as the first role in the list.
    # Keep that in mind if you update this list.
    def roles = %w[viewer lab_supervisor square_supervisor area_supervisor dig_director superuser]

    def default_role = roles.first

    def id_fields = %w[provider uid]

    # `attr_accessor` pulls from this list. To add a new attribute, update it here.
    def data_fields = id_fields + %w[email name roles _rev]

    def where(provider: nil, uid: nil)
      start_key = if provider
                    uid ? [provider, uid] : [provider]
                  else
                    []
                  end
      end_key = start_key + [{}]
      rows = CouchDB.auth_db.view(collection_name, { start_key: start_key, end_key: end_key, reduce: false })['rows']
      rows.map { |row| from_document(row['value']) }
    end

    # Expects either:
    # 1. A hash of the form {"provider" => string, "uid" => string}
    # 2. A string of the form "provider__uid" (note the double underscore)
    def find(id)
      if id.is_a? Hash
        find_by(**id.transform_keys(&:to_sym))
      else
        find_by(provider: id.split('__').first, uid: id.split('__').last)
      end
    end

    # Find a specific user
    def find_by(provider: nil, uid: nil)
      result = where(provider: provider, uid: uid).first
      if result&.id == { "provider" => provider, "uid" => uid }
        result
      else
        nil
      end
    end

    def find_or_create_by(**options)
      # Options other than provider and uid are ignored for lookup, but will be used for creation if no existing record is found.
      find_by(provider: options[:provider], uid: options[:uid]) || from_document(options)
    end

    def find_all
      where
    end
  end

  # To add a new attribute, add it to `User.data_fields` above
  attr_accessor(*User.data_fields)

  validates :provider, presence: true
  validates :uid, presence: true
  validates :email, presence: true
  validates :name, presence: true
  validates :roles, presence: true
  validate :uid_and_provider_combined_must_be_unique
  validate :roles_must_have_valid_structure

  def to_document
    deep_stringify_keys(                      # CouchDB and this model expect string keys
      User.data_fields
          .index_with { |field| send(field) } # Stored fields (calls attribute accessors)
          .merge(_id: id.values.join('__'))   # Computed fields
          .compact_blank
    )
  end

  def initialize(attributes = {}, persist: true, **kwargs)
    super(deep_stringify_keys(attributes.merge(kwargs)))

    @roles ||= { opendig: [User.default_role] }
    
    # CouchDB expects 'save' actions for existing documents to have a `_rev` attached.
    # `synchronize!` will pick this up if that is the case. This enables `User.new` to
    # be idempotent for existing users.
    if persist
      synchronize!
      save!
    end

    # Whether the user has already been saved or was loaded directly from CouchDB
    @initially_persisted = persist || attributes.keys.include?('_rev')
  end

  def id
    as_json(only: self.class.id_fields)
  end

  def save!
    validate!

    synchronize! unless @initially_persisted # For idempotence--same reasoning as in `User.new`
    response = CouchDB.auth_db.save_doc(to_document)
    synchronize!

    if response['ok']
      true
    else
      errors.add(:base, "Failed to save user: #{response['error']}")
      raise NotSaved, "Failed to save user: #{response['error']}"
    end
  end

  # Sync with CouchDB--update this object so that it's in line with CouchDB.
  def synchronize!
    updated_record = self.class.find_by(provider: provider, uid: uid)
    replace updated_record if updated_record
    validate!
    !!updated_record
  end

  # Similar to Array#replace. Replaces this object's attributes with the attributes of the other user. Does not save to CouchDB.
  def replace(other)
    %i[uid provider email name roles _rev].each do |field|
      # We use `send` over `instance_variable_set` because ActiveModel
      # monkeypatches attribute accessors
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

    id == other.id
  end

  def role
    roles[current_dig]&.first.to_s || User.default_role
  end

  def role_scopes
    role = roles[current_dig] || []
    role[1..] || []
  end

  def role_at_least?(role)
    User.roles.index(self.role) >= User.roles.index(role.to_s)
  end

  class NotSaved < StandardError; end

  private

  def uid_and_provider_combined_must_be_unique
    # Query CouchDB directly since `where` calls `new` and `new` triggers validations
    # Using `where` would cause infinite recursion
    existing_users = CouchDB.auth_db.view(self.class.collection_name, { key: [provider, uid] })['rows']
    return unless existing_users.any? { |user| user['provider'] == provider && user['uid'] == uid }

    errors.add(:base, "A user with provider '#{provider}' and uid '#{uid}' already exists.")
  end

  def roles_must_have_valid_structure
    unless roles.keys.include?(current_dig)
      errors.add(:roles, "must include the current dig")
    end

    unless roles.values.all? { |value| value.is_a?(Array) && User.roles.include?(value.first.to_s) }
      errors.add(:roles, "must include only allowed roles")
    end
  end

  def deep_stringify_keys(hash)
    hash.transform_keys(&:to_s).transform_values do |value|
      value.is_a?(Hash) ? deep_stringify_keys(value) : value
    end
  end

  # Not sure how handling multiple digs will work ATP.
  # This is good enough to get per-dig permissions going.
  # Needs refactoring later.
  def current_dig
    'opendig'
  end
end
