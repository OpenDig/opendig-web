# An invitation pre-authorizes an email address for a role on a project ("dig").
# Because login is OAuth-only, an invitation is an email-match pre-authorization:
# no email is sent. When the invited person next signs in with a matching email,
# `User#apply_pending_invitations!` applies the role and marks the invitation
# accepted (see SessionsController#create).
#
# Invitations are stored in the shared auth database (`CouchDB.auth_db`) alongside
# users, distinguished by `type: 'invitation'`. The `_id` is deterministic per
# project+email so re-inviting the same address updates the existing record.
class Invitation
  include ActiveModel::Model

  STATUSES = %w[pending accepted].freeze

  attr_accessor :email, :project, :role, :scopes, :invited_by, :status, :created_at, :accepted_at, :_rev

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :project, presence: true
  validate :role_must_be_assignable

  class NotSaved < StandardError; end

  class << self
    # `doc` may be a plain Hash (from a view's row value) or a CouchRest::Document
    # (from #get); both support string-key access, which is all we use.
    def from_document(doc)
      new(
        email: doc['email'], project: doc['project'], role: doc['role'],
        scopes: doc['scopes'], invited_by: doc['invited_by'], status: doc['status'],
        created_at: doc['created_at'], accepted_at: doc['accepted_at'], _rev: doc['_rev']
      )
    end

    # Pending invitations matching an email, across all projects (used at login).
    def pending_for(email)
      return [] if email.blank?

      rows = CouchDB.auth_db.view('authdb/invitations_by_email', key: email.to_s.downcase, reduce: false)['rows']
      rows.map { |row| from_document(row['value']) }
    rescue CouchRest::NotFound, CouchRest::BadRequest => e
      Rails.logger.error "Invitation.pending_for failed: #{e.class}: #{e.message}"
      []
    end

    # Invitations for a project with the given status (used to list them).
    def for_project(project, status: 'pending')
      rows = CouchDB.auth_db.view('authdb/invitations_by_project', key: [project.to_s, status], reduce: false)['rows']
      rows.map { |row| from_document(row['value']) }
    rescue CouchRest::NotFound, CouchRest::BadRequest => e
      Rails.logger.error "Invitation.for_project failed: #{e.class}: #{e.message}"
      []
    end

    def document_id(project, email)
      "invitation__#{project}__#{email.to_s.downcase}"
    end

    def find(project, email)
      doc = begin
        CouchDB.auth_db.get(document_id(project, email))
      rescue StandardError
        nil
      end
      doc && from_document(doc)
    end
  end

  def initialize(attributes = {})
    super(attributes.to_h.symbolize_keys)
    @email = @email.to_s.downcase.presence
    @scopes = Array(@scopes).reject(&:blank?)
    @status = 'pending' if @status.blank?
    @created_at = Time.current.iso8601 if @created_at.blank?
  end

  def id = self.class.document_id(project, email)

  def to_document
    {
      '_id' => id,
      '_rev' => _rev.presence,
      'type' => 'invitation',
      'email' => email,
      'project' => project,
      'role' => role,
      'scopes' => scopes,
      'invited_by' => invited_by,
      'status' => status,
      'created_at' => created_at,
      'accepted_at' => accepted_at
    }.compact
  end

  def save!
    validate!
    sync_rev! # pick up the current _rev so re-inviting overwrites cleanly
    response = CouchDB.auth_db.save_doc(to_document)
    raise NotSaved, response['error'] unless response['ok']

    @_rev = response['rev']
    true
  end

  def save
    save!
  rescue NotSaved, ActiveModel::ValidationError
    false
  end

  def accept!
    @status = 'accepted'
    @accepted_at = Time.current.iso8601
    save!
  end

  def revoke!
    doc = begin
      CouchDB.auth_db.get(id)
    rescue StandardError
      nil
    end
    CouchDB.auth_db.delete_doc(doc) if doc
  end

  def pending? = status == 'pending'

  private

  def sync_rev!
    existing = begin
      CouchDB.auth_db.get(id)
    rescue StandardError
      nil
    end
    @_rev = existing['_rev'] if existing
  end

  def role_must_be_assignable
    return if User.roles.include?(role.to_s)

    errors.add(:role, 'is not a valid role')
  end
end
