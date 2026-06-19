# Roles:
# - Superuser (full admin)
# - Dig director (admin for particular dig)
# - Area director (editor for particular area)
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
  include ActiveModel::SecurePassword # provides has_secure_password for this plain ActiveModel class

  # The provider value used for self-service email/password accounts (vs OAuth providers).
  EMAIL_PROVIDER = 'email'

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

    # Roles are defined here in order of increasing permissions. The default role
    # is taken as the first role in the list. NOTE: `registrar` does not fit a
    # strict linear hierarchy (it has full registrar-tool access but cannot edit
    # excavation data), so capability predicates -- not `role_at_least?` -- govern
    # registrar vs. supervisor permissions. The ordering here is used only where
    # a linear comparison still makes sense (viewer/supervisors/dig_director/superuser).
    def roles = %w[viewer square_supervisor area_supervisor registrar dig_director superuser]

    def default_role = roles.first

    # The fallback project key used before a request has resolved one (e.g. some
    # background/seed paths). Real requests set the project from the subdomain.
    def default_dig = 'opendig'

    def role_scopes_for(role, project: CouchDB.current_project)
      case role.to_s
      when 'dig_director'
        # Dig directors (and registrars) are scoped to the whole project, which is
        # determined by the subdomain. The only "scope" is the project itself.
        { project.to_s.humanize => project.to_s }
      when 'area_supervisor'
        CouchDB.main_db.view('opendig/areas', { group: true })['rows'].map { |row| ["Area #{row['key']}", row['key']] }.to_h
      when 'square_supervisor'
        CouchDB.main_db.view('opendig/squares', { group: true })['rows'].map { |row| ["Square #{row['key'].join('.')}", row['key'].join('.')] }.to_h
      end
      # Other roles (viewer, registrar, superuser) need no specific scope selection.
    end

    def id_fields = %w[provider uid]

    # `attr_accessor` pulls from this list. To add a new attribute, update it here.
    def data_fields = id_fields + %w[email name roles password_digest _rev]

    # Build (unsaved) a self-service email/password user. Call `save` to persist.
    def register(email:, password:, name:, password_confirmation: nil)
      normalized = email.to_s.strip.downcase
      user = new(provider: EMAIL_PROVIDER, uid: normalized, email: normalized, name: name, persist: false)
      user.password = password
      user.password_confirmation = password_confirmation unless password_confirmation.nil?
      user
    end

    # Return the email/password user if the password matches, else nil.
    def authenticate_email(email, password)
      return nil if email.blank? || password.blank?

      user = find_by(provider: EMAIL_PROVIDER, uid: email.to_s.strip.downcase)
      user&.authenticate(password) || nil
    end

    def where(provider: nil, uid: nil)
      start_key = if provider
                    uid ? [provider, uid] : [provider]
                  else
                    []
                  end
      end_key = start_key + [{}]
      begin
        rows = CouchDB.auth_db.view(collection_name, { start_key: start_key, end_key: end_key, reduce: false })['rows']
      rescue CouchRest::BadRequest => e
        Rails.logger.error "CouchDB BadRequest in User.where: #{e.class}: #{e.message}"
        return []
      end

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
      return unless result&.id == { 'provider' => provider, 'uid' => uid }

      result
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

  # The project ("dig") this user is being viewed/edited in the context of. Set
  # per-request from the resolved subdomain (see ApplicationController#current_user).
  # Not persisted -- it scopes which entry of the `roles` hash is consulted.
  attr_writer :current_dig

  # Adds `password=`, `password_confirmation=`, and `authenticate`. validations:
  # false because OAuth users have no password; email users are validated below.
  has_secure_password validations: false

  validates :provider, presence: true
  validates :uid, presence: true
  validates :email, presence: true
  validates :name, presence: true
  validates :roles, presence: true
  validate :uid_and_provider_combined_must_be_unique
  validate :roles_must_have_valid_structure
  validate :password_rules_for_email

  def to_document
    deep_stringify_keys(                      # CouchDB expects string keys
      User.data_fields
          .index_with { |field| send(field) } # Stored fields (calls attribute accessors)
          .merge(_id: id.values.join('__'))   # Computed fields
          .compact_blank
    )
  end

  def initialize(attributes = {}, persist: true, **kwargs)
    super(deep_stringify_keys(attributes).merge(deep_stringify_keys(kwargs)))

    @roles ||= { current_dig => [User.default_role] }

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

  def id_as_string
    id.values.join('__')
  end

  def save!
    validate!

    synchronize! unless @initially_persisted # For idempotence--same reasoning as in `User.new`
    response = CouchDB.auth_db.save_doc(to_document)
    synchronize!

    if response['ok']
      true
    else
      msg = "Failed to save user: #{response['error']}"
      errors.add(:base, msg)
      raise NotSaved, msg
    end
  end

  # Update this object so that it's in line with CouchDB
  def synchronize!
    updated_record = self.class.find(id)
    replace updated_record if updated_record
    validate!
    !!updated_record
  end

  def update(attributes, **)
    update!(attributes, **)
  rescue NotSaved, ActiveModel::ValidationError
    false
  end

  # Similar to Array#replace. Replaces this object's attributes with the attributes of the other user. Does not save to CouchDB.
  def replace(other)
    self.class.data_fields.each do |field|
      # We use `send` over `instance_variable_set` because ActiveModel
      # monkeypatches attribute accessors
      send(:"#{field}=", other.send(field))
    end
  end

  def update!(attributes, **kwargs)
    attributes = deep_stringify_keys(attributes.merge(kwargs))

    # Process custom fields
    role = attributes.fetch('role', nil)
    scopes = attributes.fetch('scopes', nil)&.compact_blank
    if role
      Rails.logger.info "    Found role assignment: #{role} with scopes: #{scopes}"
      attributes['roles'] ||= {}
      attributes['roles'][current_dig] = [role]
      # Don't carry over scopes if role is changing
      attributes['roles'][current_dig] += scopes || [] if role.to_s == self.role.to_s
      Rails.logger.info "    Updated roles: #{attributes['roles']}"
    end

    attributes.slice!(*User.data_fields)
    attributes.each { |field, value| send(:"#{field}=", value) }
    save!

    self
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
    # A user with no entry for the current project is treated as a plain viewer.
    roles[current_dig]&.first&.to_s || User.default_role
  end

  def role_scopes
    # Special case--dig directors and superusers have digs as role scopes, but they're specified at the top level of the roles hash rather than in an array like scopes for other roles since roles overall are scoped per dig.
    return [current_dig] if %w[dig_director superuser].include? role

    role = roles[current_dig] || []
    role[1..] || []
  end

  def role_at_least?(role)
    User.roles.index(self.role) >= User.roles.index(role.to_s)
  end

  # Role/scopes for an arbitrary project (not just the current one). Used when
  # building a paired device's multi-project configuration bundle.
  def role_for(project)
    roles[project.to_s]&.first&.to_s || User.default_role
  end

  def scopes_for(project)
    (roles[project.to_s] || [])[1..] || []
  end

  # --- Role predicates (for the current project, except superuser?) ---

  # Superuser is global: a superuser entry under ANY project grants it everywhere.
  def superuser? = roles.values.any? { |entry| Array(entry).first.to_s == 'superuser' }

  def dig_director?    = role == 'dig_director'
  def registrar?       = role == 'registrar'
  def area_supervisor? = role == 'area_supervisor'
  def square_supervisor? = role == 'square_supervisor'

  # --- Capability predicates ---

  # Supervisors can read the registrar tools; registrars/dig directors/superusers
  # can also write. Plain viewers have no registrar access.
  def can_view_registrar? = can_edit_registrar? || area_supervisor? || square_supervisor?

  # Only registrars, dig directors and superusers can modify registrar data.
  def can_edit_registrar? = superuser? || dig_director? || registrar?

  # Excavation data (loci/areas/squares). Registrars are explicitly read-only here.
  def can_edit_dig_data?(area: nil, square: nil)
    return true if superuser? || dig_director?
    return scope_covers?(area: area, square: square) if area_supervisor? || square_supervisor?

    false
  end

  # Assigning roles to users for the project.
  def can_manage_roles? = superuser? || dig_director?

  # A dig director may assign any project role except superuser; only a superuser
  # can grant superuser.
  def can_assign_role?(target_role)
    return true if superuser?

    can_manage_roles? && target_role.to_s != 'superuser'
  end

  # Does this user's scope cover the given area (string) / square ([area, square])?
  # Scope representations seen in practice:
  #   - area scope: a plain string, e.g. "1"
  #   - square scope: an array ["1", "1"] (fixtures) or a joined string "1.1" (admin form)
  #   - dig-level scope: equals the current project key
  def scope_covers?(area:, square: nil)
    area = area.to_s
    square = square&.to_s
    target_square = [area, square].join('.') if square.present?
    role_scopes.any? do |user_scope|
      if user_scope.is_a?(Array)
        square.present? && user_scope.map(&:to_s) == [area, square]
      elsif user_scope.to_s.include?('.')
        user_scope.to_s == target_square
      else
        user_scope.to_s == area || user_scope.to_s == current_dig
      end
    end
  end

  # Apply any pending invitations matching this user's email. Each invitation sets
  # this user's role (and scopes) for the invitation's project; the invitation is
  # then marked accepted. Called at login (SessionsController#create). No-op when
  # there are no pending invitations. Returns the applied invitations.
  def apply_pending_invitations!
    invitations = Invitation.pending_for(email)
    return [] if invitations.empty?

    self.roles ||= {}
    invitations.each do |invitation|
      roles[invitation.project] = [invitation.role, *invitation.scopes].compact
    end
    save!
    invitations.each(&:accept!)
    invitations
  end

  class NotSaved < StandardError; end

  private

  def uid_and_provider_combined_must_be_unique
    # Query CouchDB directly since `where` calls `new` and `new` triggers validations
    # Using `where` would cause infinite recursion
    begin
      existing_users = CouchDB.auth_db.view(self.class.collection_name, { key: [provider, uid] })['rows']
    rescue CouchRest::BadRequest => e
      Rails.logger.error "CouchDB BadRequest in uid uniqueness check: #{e.class}: #{e.message}"
      return
    end

    return unless existing_users.any? { |user| user['provider'] == provider && user['uid'] == uid }

    errors.add(:base, "A user with provider '#{provider}' and uid '#{uid}' already exists.")
  end

  def password_rules_for_email
    return unless provider.to_s == self.class::EMAIL_PROVIDER

    return errors.add(:password, "can't be blank") if password_digest.blank?

    errors.add(:password, 'must be at least 8 characters') if @password.present? && @password.length < 8
    return unless @password.present? && !@password_confirmation.nil? && @password != @password_confirmation

    errors.add(:password_confirmation, "doesn't match password")
  end

  def roles_must_have_valid_structure
    # A user need not have an entry for every project -- absence means "viewer"
    # for that project. We only require that whatever entries exist are well-formed.
    errors.add(:roles, 'must include only allowed roles') unless roles.values.all? { |value| value.is_a?(Array) && User.roles.include?(value.first.to_s) }
  end

  def deep_stringify_keys(hash)
    hash.transform_keys(&:to_s).transform_values do |value|
      value.is_a?(Hash) ? deep_stringify_keys(value) : value
    end
  end

  # The project context for role lookups. Set per-request via `current_dig=`
  # (from the resolved subdomain); falls back to the thread-local current project,
  # then to a default for request-less paths.
  def current_dig
    @current_dig || CouchDB.current_project || User.default_dig
  end
end
