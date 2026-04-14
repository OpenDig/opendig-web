# doc.area, doc.square, doc.code, doc._id, doc.locus_type, doc.designation, doc.age

class Locus
  attr_accessor :area, :square, :code, :id, :locus_type, :designation, :age

  def initialize(row)
    @area, @square, @code, @id, @locus_type, @designation, @age = row
  end

  def to_ary
    [area, square, code, id, locus_type, designation, age]
  end

  def self.all
    Rails.application.config.couchdb.view('opendig/all_loci')['rows'].map { |locus| locus['key'] }
  end
end
