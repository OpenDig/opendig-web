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

  class << self
    def collection_name
      'authdb/users'
    end

    def from_omniauth(auth)
      find_by(provider: auth.provider, uid: auth.uid) ||
        new({
              provider: auth.provider,
              uid: auth.uid,
              email: auth.info.email,
              name: auth.info.name
            })
    end

    def from_document(doc)
      new(doc.transform_keys(&:to_s).slice(*data_fields), persist: false)
    end

    # Roles are defined here in order of increasing permissions. The default role is taken as the first role in the list.
    # Keep that in mind if you update this list.
    def roles = %w[viewer lab_supervisor square_supervisor field_supervisor dig_director superuser]

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
      rows = @authdb.view(collection_name, { start_key: start_key, end_key: end_key, reduce: false })['rows']
      rows.map { |row| from_document(row['value']) }
    end

    # Expects either:
    # 1. A hash of the form {"provider" => string, "uid" => string}
    # 2. A string of the form "provider_uid"
    def find(id)
      if id.is_a? Hash
        find_by(**id.transform_keys(&:to_sym))
      else
        find_by(provider: id.split('_').first, uid: id.split('_').last)
      end
    end

    def find_by(provider: nil, uid: nil)
      where(provider: provider, uid: uid).first
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
  validate :uid_and_provider_combined_must_be_unique

  def to_document
    deep_stringify_keys(                      # CouchDB and this model expect string keys
      User.data_fields
          .index_with { |field| send(field) } # Stored fields (calls attribute accessors)
          .merge(_id: "#{provider}_#{uid}")   # Computed fields
          .compact_blank
    )
  end

  def initialize(attributes = {}, persist: true)
    super(deep_stringify_keys(attributes))

    @roles ||= { opendig: [User.default_role] }
    save! if persist
  end

  def id
    as_json(only: self.class.id_fields)
  end

  def save!
    validate!

    response = Rails.application.config.authdb.save_doc(to_document)
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
    replace updated_record
    validate!
  end

  # Similar to Array#replace. Replaces this object's attributes with the attributes of the other user. Does not save to CouchDB.
  def replace(other)
    [:uid, :provider, :email, :name, :roles, :_rev].each do |field|
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
    roles[current_dig]&.first || User.default_role
  end

  def role_scopes
    role = roles[current_dig] || []
    role[1..] || []
  end

  def role_at_least?(role)
    User.roles.index(roles[current_dig]&.first || User.default_role) >= User.roles.index(role)
  end

  class NotSaved < StandardError; end

  private

  def uid_and_provider_combined_must_be_unique
    # Query CouchDB directly since `where` calls `new` and `new` triggers validations
    # which would cause infinite recursion
    existing_users = @authdb.view(self.class.collection_name, { key: [provider, uid] })['rows']
    return unless existing_users.any? { |user| user['provider'] == provider && user['uid'] == uid }

    errors.add(:base, "A user with provider '#{provider}' and uid '#{uid}' already exists.")
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
    "opendig"
  end
end
