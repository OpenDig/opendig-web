# Project (multi-tenant) database management.
#
# Each project is a CouchDB database named "#{key}_#{env}" (see app/models/project.rb).
# These tasks create/seed those databases for local development. Requires a running
# CouchDB (see docker-compose.yml).
namespace :projects do
  desc 'List project keys for the current environment'
  task list: :environment do
    keys = Project.all
    puts keys.any? ? keys.join("\n") : '(no projects found)'
  end

  desc "Create a project database and install design docs. Usage: rake 'projects:create[balua]'"
  task :create, [:key] => :environment do |_t, args|
    key = args[:key]
    abort "Usage: rake 'projects:create[key]'" if key.blank?

    db_name = Project.database_name(key)
    CouchDB.new(env: CouchDB.env, db_name: db_name)
    Project.reset_cache!
    puts "Created #{db_name} (design docs installed)."
  end

  desc "Replicate one project db into another (creating it). Usage: rake 'projects:replicate[opendig,balua]'"
  task :replicate, %i[source_key target_key] => :environment do |_t, args|
    source_key = args[:source_key]
    target_key = args[:target_key]
    abort "Usage: rake 'projects:replicate[source_key,target_key]'" if source_key.blank? || target_key.blank?

    server = CouchDB.server
    source = server.database!(Project.database_name(source_key))
    target = server.database!(Project.database_name(target_key))
    # Post _replicate with fully-qualified source/target URLs (couchrest's
    # replicate_to passes the source as a bare name, which CouchDB 3.x rejects).
    server.connection.post('_replicate',
                           source: source.root.to_s,
                           target: target.root.to_s,
                           create_target: true)
    Project.reset_cache!
    puts "Replicated #{source.name} -> #{target.name}."
  end

  desc 'Seed development project databases (balua from the legacy opendig db, plus an empty umayri).'
  task seed_dev: :environment do
    abort 'projects:seed_dev is for the development environment only' unless CouchDB.env == 'development'

    Rake::Task['projects:replicate'].invoke('opendig', 'balua')
    Rake::Task['projects:create'].invoke('umayri')
    puts 'Done. Visit http://balua.lvh.me:3000 and http://umayri.lvh.me:3000'
  end
end
