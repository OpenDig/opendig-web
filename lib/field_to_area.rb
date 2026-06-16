class FieldToArea

  def initialize
    @db = CouchDB.main_db
  end

  def migrate
    docs = @db.all_docs
    docs["rows"].each do |row|
      doc = @db.get(row["id"])
      doc["area"] = doc["field"]
      doc.save
    end
  end

end