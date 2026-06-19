# A short-lived, single-use code a signed-in user generates to pair a mobile
# device (see DevicesController). The device redeems it via the API to receive a
# token + configuration bundle. Stored in the shared auth database.
class PairingCode
  include ActiveModel::Model

  CODE_LENGTH = 8
  TTL = 10.minutes
  # Unambiguous alphabet (no 0/O/1/I) since a human types the code into a device.
  ALPHABET = (('A'..'Z').to_a + ('2'..'9').to_a - %w[I O]).freeze

  attr_accessor :code, :user_id, :device_name, :expires_at, :created_at, :_rev

  validates :code, presence: true
  validates :user_id, presence: true

  class << self
    def generate_for(user, device_name: nil)
      code = new(
        code: random_code,
        user_id: user.id_as_string,
        device_name: device_name.presence,
        expires_at: (Time.current + TTL).iso8601,
        created_at: Time.current.iso8601
      )
      code.save!
      code
    end

    # Returns the (now-consumed) code if it exists and is unexpired, else nil.
    # Single-use: the record is deleted on redemption.
    def redeem(raw_code)
      code = find(raw_code)
      return nil unless code&.active?

      code.destroy!
      code
    end

    def find(raw_code)
      return nil if raw_code.blank?

      doc = begin
        CouchDB.auth_db.get(document_id(raw_code))
      rescue StandardError
        nil
      end
      doc && from_document(doc)
    end

    def document_id(raw_code) = "pairing_code__#{raw_code.to_s.upcase}"

    def from_document(doc)
      new(code: doc['code'], user_id: doc['user_id'], device_name: doc['device_name'],
          expires_at: doc['expires_at'], created_at: doc['created_at'], _rev: doc['_rev'])
    end

    private

    def random_code
      Array.new(CODE_LENGTH) { ALPHABET[SecureRandom.random_number(ALPHABET.size)] }.join
    end
  end

  def id = self.class.document_id(code)

  def active?
    expires_at.present? && Time.current < Time.zone.parse(expires_at.to_s)
  end

  def user = User.find(user_id)

  def to_document
    {
      '_id' => id,
      '_rev' => _rev.presence,
      'type' => 'pairing_code',
      'code' => code,
      'user_id' => user_id,
      'device_name' => device_name,
      'expires_at' => expires_at,
      'created_at' => created_at
    }.compact
  end

  def save!
    validate!
    response = CouchDB.auth_db.save_doc(to_document)
    raise "Failed to save pairing code: #{response['error']}" unless response['ok']

    @_rev = response['rev']
    self
  end

  def destroy!
    doc = begin
      CouchDB.auth_db.get(id)
    rescue StandardError
      nil
    end
    CouchDB.auth_db.delete_doc(doc) if doc
  end
end
