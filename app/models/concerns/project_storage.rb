require "securerandom"

# Project-scoped S3 object-key prefixes. All projects share one bucket (default
# "opendig"); each project's files live under <project>/finds/... (find images),
# <project>/daily_photos/... (official daily photos) and <project>/user_photos/...
# (unofficial field photos taken on a paired device) so projects -- and the
# official vs. user photo categories -- never collide. The project is the one
# resolved from the request subdomain (CouchDB.current_project).
module ProjectStorage
  module_function

  def storage_project
    project = CouchDB.current_project
    raise 'No current project resolved for S3 storage path' if project.blank?

    project
  end

  def finds_prefix
    "#{storage_project}/finds"
  end

  def daily_photos_prefix
    "#{storage_project}/daily_photos"
  end

  # Unofficial, device-only field photos. Kept under a distinct prefix so they
  # are always separable from the official daily_photos and can be displayed
  # apart from them.
  def user_photos_prefix
    "#{storage_project}/user_photos"
  end

  # Canonical key for a user-taken field photo. Self-describing so an object is
  # attributable even detached from its locus record: locus, uploader and capture
  # time are encoded, with a short random nonce so burst/offline shots in the same
  # second never collide. Devices generate names to this same contract offline.
  def user_photo_key(locus:, user_id:, taken_at:, ext: "jpg", nonce: SecureRandom.hex(3))
    stamp = taken_at.utc.strftime("%Y%m%dT%H%M%SZ")
    name  = "#{key_slug(locus)}-#{key_slug(user_id)}-#{stamp}-#{nonce}.#{ext.to_s.downcase.delete_prefix('.')}"
    "#{user_photos_prefix}/#{name}"
  end

  # Reduce an identifier to characters safe and predictable in an object key.
  def key_slug(value)
    value.to_s.strip.gsub(/[^a-zA-Z0-9]+/, "_").gsub(/\A_+|_+\z/, "")
  end
end
