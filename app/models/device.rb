# A paired mobile device. Created when a device redeems a PairingCode. Holds the
# SHA-256 digest of an opaque bearer token (the raw token is shown to the device
# exactly once). Stored in the shared auth database; deleting the record revokes
# the device. See Api::V1::DevicesController and DeviceConfiguration.
require 'digest'

class Device
  include ActiveModel::Model

  attr_accessor :device_id, :user_id, :device_name, :token_digest, :created_at, :last_seen_at, :_rev

  validates :user_id, presence: true
  validates :token_digest, presence: true

  class << self
    # Returns [device, raw_token]. The raw token is never persisted.
    def create_for(user, device_name: nil)
      raw_token = SecureRandom.urlsafe_base64(32)
      device = new(
        device_id: SecureRandom.uuid,
        user_id: user.id_as_string,
        device_name: device_name.presence || 'Mobile device',
        token_digest: digest(raw_token),
        created_at: Time.current.iso8601,
        last_seen_at: Time.current.iso8601
      )
      device.save!
      [device, raw_token]
    end

    def authenticate(raw_token)
      return nil if raw_token.blank?

      rows = CouchDB.auth_db.view('authdb/devices_by_token', key: digest(raw_token), reduce: false)['rows']
      row = rows.first
      row && from_document(row['value'])
    rescue CouchRest::NotFound, CouchRest::BadRequest => e
      Rails.logger.error "Device.authenticate failed: #{e.class}: #{e.message}"
      nil
    end

    def for_user(user_id)
      rows = CouchDB.auth_db.view('authdb/devices_by_user', key: user_id.to_s, reduce: false)['rows']
      rows.map { |row| from_document(row['value']) }
    rescue CouchRest::NotFound, CouchRest::BadRequest => e
      Rails.logger.error "Device.for_user failed: #{e.class}: #{e.message}"
      []
    end

    def find(device_id)
      doc = begin
        CouchDB.auth_db.get(document_id(device_id))
      rescue StandardError
        nil
      end
      doc && from_document(doc)
    end

    def digest(raw_token) = Digest::SHA256.hexdigest(raw_token.to_s)

    def document_id(device_id) = "device__#{device_id}"

    def from_document(doc)
      new(device_id: doc['device_id'], user_id: doc['user_id'], device_name: doc['device_name'],
          token_digest: doc['token_digest'], created_at: doc['created_at'],
          last_seen_at: doc['last_seen_at'], _rev: doc['_rev'])
    end
  end

  def id = self.class.document_id(device_id)

  def user = User.find(user_id)

  def to_document
    {
      '_id' => id,
      '_rev' => _rev.presence,
      'type' => 'device',
      'device_id' => device_id,
      'user_id' => user_id,
      'device_name' => device_name,
      'token_digest' => token_digest,
      'created_at' => created_at,
      'last_seen_at' => last_seen_at
    }.compact
  end

  def save!
    validate!
    response = CouchDB.auth_db.save_doc(to_document)
    raise "Failed to save device: #{response['error']}" unless response['ok']

    @_rev = response['rev']
    self
  end

  # Best-effort last-seen update; ignore conflicts from concurrent requests.
  def touch!
    @last_seen_at = Time.current.iso8601
    save!
  rescue StandardError => e
    Rails.logger.warn "Device#touch! skipped: #{e.class}: #{e.message}"
    self
  end

  def revoke!
    doc = begin
      CouchDB.auth_db.get(id)
    rescue StandardError
      nil
    end
    CouchDB.auth_db.delete_doc(doc) if doc
  end
end
