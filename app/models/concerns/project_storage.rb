# Project-scoped S3 object-key prefixes. All projects share one bucket (default
# "opendig"); each project's files live under <project>/artifacts/... (find images)
# and <project>/daily_photos/... so projects never collide. The project is the one
# resolved from the request subdomain (CouchDB.current_project).
module ProjectStorage
  module_function

  def storage_project
    project = CouchDB.current_project
    raise 'No current project resolved for S3 storage path' if project.blank?

    project
  end

  def artifacts_prefix
    "#{storage_project}/artifacts"
  end

  def daily_photos_prefix
    "#{storage_project}/daily_photos"
  end
end
