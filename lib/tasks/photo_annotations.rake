# Seed shared per-photo annotation documents from annotations currently
# embedded on locus photos.
#
# The same physical photo is embedded into every locus it's tagged onto, so an
# annotation made in one locus was invisible in the others. Annotations now live
# in ONE `photo_annotations` doc per photo, addressed by a deterministic id
# derived from the photo's identity (S3 key, else number) — the identical scheme
# the mobile app uses (see lib/utils/photo_identity.dart):
#
#   ident = "k:<key>"  (field/user photos) or "n:<number>" (official photos)
#   _id   = "photo_anno:" + SHA1(ident)
#
# This backfills those docs by unioning every locus's embedded annotations (by
# annotation id). It does NOT strip the embedded copies — they stay as a
# read-only fallback. Idempotent (re-running unions the same ids and saves
# nothing new).
#
#   # preview, all projects:
#   RAILS_ENV=production DRY_RUN=1 bin/rails photo_annotations:migrate
#   # apply, one project:
#   RAILS_ENV=production bin/rails 'photo_annotations:migrate[balua]'
require 'digest'

namespace :photo_annotations do
  desc 'Seed shared photo_annotations docs from embedded locus annotations (DRY_RUN=1 to preview)'
  task :migrate, %i[project] => :environment do |_t, args|
    dry = ENV['DRY_RUN'].present?
    projects = args[:project].present? ? [args[:project]] : Project.all

    # Deterministic annotation-doc id for a photo (must match the mobile app).
    doc_id = lambda do |photo|
      key = photo['key'].to_s
      number = photo['number'].to_s
      ident = if key.present? then "k:#{key}"
              elsif number.present? then "n:#{number}"
              end
      ident && "photo_anno:#{Digest::SHA1.hexdigest(ident)}"
    end

    # Union two annotation lists by `id`; the already-stored copy wins on a
    # collision (all seed annotations are live, so order is all that matters).
    union = lambda do |existing, incoming|
      by_id = {}
      order = []
      (Array(existing) + Array(incoming)).each do |a|
        next unless a.is_a?(Hash)

        id = a['id'].to_s
        next if id.empty?

        order << id unless by_id.key?(id)
        by_id[id] ||= a
      end
      order.map { |id| by_id[id] }
    end

    projects.each do |project|
      CouchDB.with_project(project) do
        db = CouchDB.main_db
        ids = db.view('opendig/loci', reduce: false)['rows']
                .map { |row| row['key'][3] }.compact.uniq

        seeded = 0
        photos_seen = 0
        ids.each do |id|
          doc = begin
            db.get(id)
          rescue StandardError
            nil
          end
          next unless doc

          [doc['photos'], doc['user_photos']].each do |photos|
            next unless photos.is_a?(Array)

            photos.each do |photo|
              anns = photo['annotations']
              next unless anns.is_a?(Array) && anns.any?

              aid = doc_id.call(photo)
              next if aid.nil? # purely-local photo with no shared identity

              photos_seen += 1
              adoc = begin
                db.get(aid)
              rescue StandardError
                nil
              end
              adoc ||= {
                '_id' => aid,
                'type' => 'photo_annotations',
                'photo_key' => photo['key'],
                'photo_number' => photo['number'],
                'annotations' => [],
                'version' => 0
              }

              before = Array(adoc['annotations']).size
              adoc['annotations'] = union.call(adoc['annotations'], anns)
              adoc['photo_key'] ||= photo['key']
              adoc['photo_number'] ||= photo['number']

              # Save when this seeds new annotations or creates the doc.
              next unless adoc['annotations'].size != before || adoc['_rev'].nil?

              adoc['version'] = adoc['version'].to_i + 1
              adoc['updated_at'] = Time.now.utc.iso8601
              db.save_doc(adoc) unless dry
              seeded += 1
            end
          end
        end

        puts "#{project}: seeded/updated #{seeded} annotation doc(s) from #{photos_seen} annotated photo copy(ies)#{dry ? ' (dry run, not saved)' : ''}"
      end
    end
  end
end
