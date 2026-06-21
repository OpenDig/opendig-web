class PhotosController < ApplicationController
  before_action :require_registrar_read, only: [:review]
  before_action :require_registrar_write, only: [:associate]

  # Project-wide overview of convention-named photos and the loci they're
  # linked to. (Per-square triage lives on the loci index page.)
  def review
    @bucket_configured = Rails.application.config.try(:s3_bucket).present?
    loci = locus_index
    @photos = BulkPhoto.all.map do |entry|
      candidates = entry.name.suggest_loci(loci)
      {
        entry: entry,
        candidates: candidates.reject { |l| entry.linked_to.include?("#{l[:area]}.#{l[:square]}.#{l[:code]}") }
      }
    end
    @photos.sort_by! { |p| [p[:candidates].empty? ? 1 : 0, p[:entry].key] }
    @unlinked_count = @photos.count { |p| p[:entry].pending? }
  end

  # Link an S3 photo to one or more loci (a photo can belong to many) by
  # appending it to each locus doc's photos[].
  def associate
    key = params[:key].to_s
    locus_ids = Array(params[:locus_ids]).compact_blank
    return_to = params[:return_to].presence || photos_review_path
    return redirect_to(return_to, alert: 'Pick at least one locus for the photo.') if key.blank? || locus_ids.empty?

    name = PhotoName.parse(File.basename(key))
    linked = []
    locus_ids.each do |id|
      doc = @db.get(id)
      doc['photos'] ||= []
      next if doc['photos'].any? { |p| p['key'] == key }

      doc['photos'] << {
        'key' => key,
        'filename' => File.basename(key),
        'subject' => name.subject,
        'date' => name.date,
        'source' => 'bulk'
      }
      @db.save_doc(doc)
      linked << "#{doc['area']}.#{doc['square']}.#{doc['code']}"
    end

    redirect_to return_to, notice: "Linked #{File.basename(key)} to #{linked.join(', ')}."
  rescue StandardError => e
    redirect_to return_to, alert: "Could not link photo: #{e.message}"
  end

  private

  # All loci as {area, square, code, id} for suggestion matching.
  def locus_index
    @db.view('opendig/loci')['rows'].map do |row|
      area, square, code, id = row['key']
      { area: area, square: square, code: code, id: id }
    end
  rescue StandardError
    []
  end
end
