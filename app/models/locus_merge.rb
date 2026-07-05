# Loss-safe merge of an edited locus form's params into the stored locus doc.
#
# The whole locus (pails -> finds -> readings, plus levels, supplements, photos,
# descriptions) lives in ONE CouchDB document, and an edit form only renders a
# subset of each embedded item's fields. A plain `deep_merge` REPLACES arrays
# wholesale, so saving the locus form used to wipe every find's photos[],
# cover_key and registration state (and any other unrendered field) — silent
# single-user data loss.
#
# Rule: the incoming (form) value is authoritative for the *set* of items in an
# array (so adds/deletes made in the form apply), but each incoming item is
# merged BY ID into the matching stored item, so fields the form didn't render
# survive. Arrays whose items have no id key (levels, readings, supplements —
# which carry no hidden data and are fully rendered) are replaced as before.
module LocusMerge
  # Stable identity keys, in priority order, used to pair an incoming item with
  # the stored one it updates.
  ID_KEYS = %w[pail_number field_number key registration_number].freeze

  module_function

  # Merge `incoming` (repaired form params) into `existing` (the stored doc),
  # preserving stored fields the form didn't submit. Both are plain Hashes with
  # string keys.
  def merge(existing, incoming)
    return incoming unless existing.is_a?(Hash) && incoming.is_a?(Hash)

    existing.merge(incoming) do |_key, old_val, new_val|
      if old_val.is_a?(Hash) && new_val.is_a?(Hash)
        merge(old_val, new_val)
      elsif old_val.is_a?(Array) && new_val.is_a?(Array) && id_key(new_val)
        merge_array_by_id(old_val, new_val)
      else
        # Scalars, type changes, and id-less arrays: the form value wins.
        new_val
      end
    end
  end

  # Take the incoming array's set/order, but merge each item into the stored item
  # with the same id so unsubmitted fields survive. Items dropped by the form are
  # dropped; items added by the form are kept as-is.
  def merge_array_by_id(old_arr, new_arr)
    key = id_key(new_arr)
    by_id = old_arr.each_with_object({}) do |item, acc|
      acc[item[key].to_s] = item if item.is_a?(Hash) && item.key?(key)
    end

    new_arr.map do |new_item|
      match = new_item.is_a?(Hash) ? by_id[new_item[key].to_s] : nil
      match ? merge(match, new_item) : new_item
    end
  end

  # The id key shared by the array's hash items, or nil if they have none.
  def id_key(arr)
    sample = arr.find { |i| i.is_a?(Hash) }
    return nil unless sample

    ID_KEYS.find { |k| sample.key?(k) }
  end
end
