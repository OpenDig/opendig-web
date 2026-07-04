# Per-project descriptions config: the static base (config/descriptions.json,
# loaded once at boot into Rails.application.config.descriptions) merged with an
# editable per-project override stored in CouchDB.
#
# A dig director edits the override on the web; the override doc is a singleton
# (`_id: "descriptions"`) in the project's main db (mirroring Project metadata),
# carrying the override hash plus a monotonically increasing `version` so clients
# can detect changes.
#
# Effective = base.deep_merge(override): nested hashes merge, while arrays and
# scalars from the override REPLACE the base — so an edited lookup list (e.g.
# `designation`) wholly replaces the default list rather than concatenating.
module ProjectDescriptions
  OVERRIDE_DOC_ID = 'descriptions'.freeze

  module_function

  # The static, deploy-time descriptions (shared default for every project).
  def base
    Rails.application.config.descriptions
  end

  # The project's effective descriptions (base + override), cached by version.
  def effective(project = CouchDB.current_project)
    return base if project.blank?

    doc = override_doc(project)
    override = doc.is_a?(Hash) ? doc['descriptions'] : nil
    return base if override.blank?

    Rails.cache.fetch("descriptions_effective/#{project}/#{doc['version']}", expires_in: 1.hour) do
      base.deep_merge(override)
    end
  end

  # The override hash a dig director saved (the parts they changed), or {}.
  def override(project = CouchDB.current_project)
    doc = override_doc(project)
    (doc.is_a?(Hash) ? doc['descriptions'] : nil) || {}
  end

  # The override version (0 when there is no override). Bumped on every save so
  # clients (the device bundle) can detect a change.
  def version(project = CouchDB.current_project)
    doc = override_doc(project)
    doc.is_a?(Hash) ? doc['version'].to_i : 0
  end

  # Store a new override hash for the project and bump the version. Returns the
  # new version.
  def save(project, override_descriptions)
    db = CouchDB.main_db(project)
    doc = db.get(OVERRIDE_DOC_ID) || { '_id' => OVERRIDE_DOC_ID, 'type' => 'descriptions', 'version' => 0 }
    doc['descriptions'] = override_descriptions
    doc['version'] = doc['version'].to_i + 1
    doc['updated_at'] = Time.current.iso8601
    db.save_doc(doc)
    clear_cache(project)
    doc['version']
  end

  # Append a value to one lookup list for the project (idempotent). Seeds the
  # override from the current EFFECTIVE list so we don't drop the base values
  # (override arrays replace, they don't merge). Returns the new version, or nil
  # when the value is blank or already present.
  def add_lookup_value(project, lookup, value)
    value = value.to_s.strip
    return if value.blank?

    list = lookup_list(project, lookup)
    return if list.include?(value)

    write_lookup_list(project, lookup, list + [value])
  end

  # Remove a value from one lookup list for the project. Returns the new version,
  # or nil when the value isn't present.
  def remove_lookup_value(project, lookup, value)
    value = value.to_s
    list = lookup_list(project, lookup)
    return unless list.include?(value)

    write_lookup_list(project, lookup, list - [value])
  end

  # The effective values for one lookup (base + override), always an array.
  def lookup_list(project, lookup)
    Array(effective(project).dig('lookups', lookup))
  end

  # Persist a lookup list into the override (seeded from effective so base values
  # survive the array-replace merge).
  def write_lookup_list(project, lookup, values)
    override = override(project).deep_dup
    override['lookups'] ||= {}
    override['lookups'][lookup] = values
    save(project, override)
  end

  # Remove the override so the project re-inherits the static defaults.
  def reset(project)
    db = CouchDB.main_db(project)
    doc = db.get(OVERRIDE_DOC_ID)
    db.delete_doc(doc) if doc
    clear_cache(project)
  end

  # The raw override doc, cached briefly (and as a sentinel when absent) so the
  # per-request set_descriptions doesn't hit CouchDB on every page load.
  def override_doc(project)
    cached = Rails.cache.read("descriptions_override/#{project}")
    return cached == :none ? nil : cached unless cached.nil?

    doc = begin
      CouchDB.main_db(project).get(OVERRIDE_DOC_ID)
    rescue StandardError
      nil
    end
    Rails.cache.write("descriptions_override/#{project}", doc || :none, expires_in: 5.minutes)
    doc
  end

  def clear_cache(project)
    Rails.cache.delete("descriptions_override/#{project}")
  end
end
