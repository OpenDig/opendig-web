# Parses the excavation photo naming convention and suggests which locus a photo
# belongs to, so bulk-uploaded photos can be auto-associated.
#
#   "B26.08.92.001.0621_Progress.JPG"
#    └─────────────────────┴ Season.Area.Square.Sequence.Date_Subject(.ext)
#
# Season carries the 2-digit year (B26 -> 2026). Area+Square (and, when it
# matches a locus code, Sequence) locate the locus. Anything that doesn't fit the
# pattern is `valid? == false` and is left for manual association.
class PhotoName
  attr_reader :filename, :season, :area, :square, :sequence, :date, :subject, :ext

  def self.parse(filename)
    new(filename)
  end

  def initialize(filename)
    @filename = filename.to_s
    base = File.basename(@filename)
    @ext = File.extname(base)
    stem = @ext.empty? ? base : base[0...(base.length - @ext.length)]
    core, subject = stem.split('_', 2)
    @subject = subject
    parts = core.to_s.split('.')
    @valid = parts.length >= 5
    @season, @area, @square, @sequence, @date = parts if @valid
  end

  def valid?
    @valid
  end

  # Calendar year from the season code, e.g. "B26" -> 2026.
  def season_year
    digits = @season.to_s[/\d+/]
    return nil unless digits

    year = digits.to_i
    year < 100 ? 2000 + year : year
  end

  # The locus this photo most likely belongs to: "area.square.sequence".
  def locus_code
    return nil unless valid?

    "#{area}.#{square}.#{sequence}"
  end

  # Candidate loci for this photo: every locus in the photo's area+square. A
  # photo can belong to many loci (Sequence is just a photo counter, not a locus
  # code), so this is a candidate set to choose from, in the loci's natural
  # order. `loci` is an array of hashes with :area, :square, :code (and :id).
  def suggest_loci(loci)
    return [] unless valid?

    loci.select do |l|
      norm(l[:area]) == norm(area) && norm(l[:square]) == norm(square)
    end
  end

  private

  # Compare codes numerically when possible so "08" == "8" and "001" == "1".
  def norm(value)
    s = value.to_s.strip
    s.match?(/\A\d+\z/) ? s.to_i.to_s : s.downcase
  end
end
