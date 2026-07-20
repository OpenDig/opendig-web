class BulkUploadsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:create] # Skip CSRF protection for AJAX requests
  before_action :require_registrar_write

  def new; end

  def create
    uploaded_files = params[:files]
    uploaded_file_keys = []
    bucket = Rails.application.config.s3_bucket
    uploaded_files.each do |file|
      s3_object = bucket.object("#{ProjectStorage.finds_prefix}/#{file.original_filename}")

      s3_object.upload_file(file.tempfile.path, acl: 'public-read') do |progress|
        # Progress tracking logic here
        # puts "Uploaded #{progress.loaded} of #{progress.total} bytes"
      end

      uploaded_file_keys << s3_object.key
      # Link the photo to its find immediately: drop the find's cached image
      # list so the new photo appears on the next load instead of waiting out
      # the 5-minute discovery cache.
      Find.clear_cache_keys(registration_from_filename(file.original_filename))
    end

    render json: { keys: uploaded_file_keys }
  end

  private

  # The find registration number a photo filename belongs to: drop the
  # extension and any trailing photo-suffix letters, so A220168.jpg, A220168.JPG
  # and the secondary A220168b.jpg all map to find A220168.
  def registration_from_filename(filename)
    File.basename(filename.to_s, '.*').sub(/[a-z]+\z/i, '')
  end
end
