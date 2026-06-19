# One-time migration from the old single-bucket layout (finds/, daily_photos/)
# to the universal-bucket, project-foldered layout (<project>/artifacts/,
# <project>/daily_photos/). Server-side S3 copy; the originals are left in place
# so you can verify before deleting them.
#
#   RAILS_ENV=production bin/rails 's3:migrate_layout[opendig-production,opendig,balua]'
#
# Args: source_bucket, target_bucket (default "opendig"), project key.
namespace :s3 do
  desc 'Migrate legacy finds/ + daily_photos/ objects into <project>/artifacts and <project>/daily_photos'
  task :migrate_layout, %i[source_bucket target_bucket project] => :environment do |_t, args|
    source_name = args[:source_bucket] || abort('source_bucket is required')
    target_name = args[:target_bucket].presence || 'opendig'
    project     = args[:project] || abort('project key is required')

    s3      = Aws::S3::Resource.new
    source  = s3.bucket(source_name)
    target  = s3.bucket(target_name)
    remaps  = { 'finds/' => "#{project}/artifacts/", 'daily_photos/' => "#{project}/daily_photos/" }
    copied  = 0

    remaps.each do |old_prefix, new_prefix|
      source.objects(prefix: old_prefix).each do |obj|
        new_key = obj.key.sub(/\A#{Regexp.escape(old_prefix)}/, new_prefix)
        target.object(new_key).copy_from(copy_source: "#{source_name}/#{obj.key}")
        copied += 1
        puts "  #{source_name}/#{obj.key}  ->  #{target_name}/#{new_key}"
      end
    end

    puts "Copied #{copied} objects. Originals left in place — verify, then delete them once confirmed."
  end
end
