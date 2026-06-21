# Migrate legacy numbered locus photos to the new key-based model.
#
# Old model: locus.photos[] entries reference a `number`; the file lives at
#   <project>/daily_photos/<number>.<ext>  and is rendered via Photo.photo_url.
# New model: entries also carry a `key` (the full S3 object key) and are
#   rendered via Photo.url_for_key — the same way convention-named photos are.
#
# The files DON'T move (they're already in daily_photos/), so this is a
# metadata-only backfill: it adds `key` (+ `filename`) to each numbered photo
# that doesn't have one yet. Idempotent.
#
#   # preview, all projects:
#   RAILS_ENV=production DRY_RUN=1 bin/rails photos:backfill_keys
#   # apply, one project:
#   RAILS_ENV=production bin/rails 'photos:backfill_keys[balua]'
namespace :photos do
  desc 'Backfill key-based references onto legacy numbered locus photos (DRY_RUN=1 to preview)'
  task :backfill_keys, %i[project] => :environment do |_t, args|
    dry = ENV['DRY_RUN'].present?
    projects = args[:project].present? ? [args[:project]] : Project.all

    projects.each do |project|
      CouchDB.with_project(project) do
        db = CouchDB.main_db
        ids = db.view('opendig/loci', reduce: false)['rows']
                .map { |row| row['key'][3] }.compact.uniq

        loci_changed = 0
        photos_fixed = 0
        ids.each do |id|
          doc = (db.get(id) rescue nil)
          next unless doc && doc['photos'].is_a?(Array)

          changed = false
          doc['photos'].each do |photo|
            next if photo['key'].present? # already migrated / convention photo

            number = photo['number'].to_s
            next if number.blank?

            key = Photo.object_key_for(number) ||
                  "#{ProjectStorage.daily_photos_prefix}/#{number}.JPG"
            photo['key'] = key
            photo['filename'] ||= File.basename(key)
            changed = true
            photos_fixed += 1
          end

          if changed
            loci_changed += 1
            db.save_doc(doc) unless dry
          end
        end

        puts "#{project}: #{photos_fixed} photo(s) on #{loci_changed} locus/loci#{dry ? ' (dry run, not saved)' : ''}"
      end
    end
  end
end
