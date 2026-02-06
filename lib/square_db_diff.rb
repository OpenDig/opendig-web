class Hash
  def deep_diff(b)
    a = self
    (a.keys | b.keys).each_with_object({}) do |k, diff|
      next unless a[k] != b[k]

      diff[k] = if a[k].respond_to?(:deep_diff) && b[k].respond_to?(:deep_diff)
                  a[k].deep_diff(b[k])
                else
                  [a[k], b[k]]
                end
    end
  end
end

class SquareDbDiff
  attr_accessor :primary_db, :backup_db, :primary_loci, :backup_loci, :area, :square, :changed_loci, :diff_hash

  def initialize(primary_db, backup_db, area, square)
    @primary_db = CouchRest.database(primary_db)
    @backup_db  = CouchRest.database(backup_db)
    @area = area
    @square = square
    @primary_loci = get_loci_for_square(@primary_db)
    @backup_loci  = get_loci_for_square(@backup_db)
    @changed_loci = get_changed_loci
    @diff_hash = build_diff_hash
  end

  def get_loci_for_square(database)
    database.view('opendig/loci',
                  { group: true, start_key: [@area, @square], end_key: [@area, @square, {}] })['rows'].map do |row|
      _doc = database.get(row['key'][3])
      { id: _doc['_id'], revision: _doc['_rev'], locus: "#{row['key'][0]}.#{row['key'][1]}.#{row['key'][2]}" }
    end.sort_by! do |l|
      l[:locus]
    end
  end

  def get_changed_loci
    @primary_loci.select { |locus| @backup_loci.none? { |backup_locus| backup_locus[:revision] == locus[:revision] } }
  end

  def build_diff_hash
    @changed_loci.map do |locus|
      { locus: locus[:locus], diff: deep_diff(locus[:id]) }
    end
  end

  def deep_diff(id)
    primary_doc = @primary_db.get(id)
    backup_doc = @backup_db.get(id)
    primary_doc.to_enum.to_h.deep_diff(backup_doc.to_enum.to_h)
  end
end
