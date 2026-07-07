require 'digest'

# Shared per-photo annotation documents (type: photo_annotations).
#
# The same physical photo is embedded on every locus it's tagged onto, so
# annotations live in ONE doc per photo, addressed by a deterministic id derived
# from the photo's identity — the identical scheme the mobile app uses
# (od_flutter lib/utils/photo_identity.dart) and the migration rake:
#
#   ident = "k:<key>" (field/user photos) or "n:<number>" (official photos)
#   _id   = "photo_anno:" + SHA1(ident)
module PhotoAnnotations
  module_function

  # Deterministic annotation-doc id for a photo, or nil for a photo with no
  # shared identity (a purely-local capture never uploaded).
  def doc_id(photo)
    key = photo['key'].to_s
    number = photo['number'].to_s
    ident = if key.present? then "k:#{key}"
            elsif number.present? then "n:#{number}"
            end
    ident && "photo_anno:#{Digest::SHA1.hexdigest(ident)}"
  end

  # Live (non-tombstoned) annotations for each of `photos`, keyed by the photo
  # object. Reads the shared docs in ONE bulk request; falls back to any copy
  # still embedded on the locus (pre-migration) when a photo has no shared doc.
  def for_photos(photos, db: CouchDB.main_db)
    photos = Array(photos).compact
    ids = photos.filter_map { |p| doc_id(p) }.uniq
    stored = ids.empty? ? {} : fetch(ids, db)

    photos.index_with do |photo|
      id = doc_id(photo)
      anns = (id && stored[id]) || photo['annotations']
      Array(anns).select { |a| a.is_a?(Hash) && a['deleted'] != true }
    end
  end

  # id => annotations[] for the docs that exist, in one _all_docs request.
  def fetch(ids, db)
    rows = db.all_docs(include_docs: true, keys: ids)['rows']
    rows.each_with_object({}) do |row, acc|
      doc = row['doc']
      acc[doc['_id']] = doc['annotations'] if doc.is_a?(Hash) && doc['annotations']
    end
  rescue StandardError
    {}
  end
end
