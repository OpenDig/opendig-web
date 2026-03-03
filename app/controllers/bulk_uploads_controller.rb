class BulkUploadsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:create] # Skip CSRF protection for AJAX requests
  before_action :require_editor

  def new
  end

  def create
    uploaded_files = params[:files]
    uploaded_file_keys = []
    bucket = Rails.application.config.s3_bucket
    uploaded_files.each do |file|
      s3_object = bucket.object("finds/#{file.original_filename}")

      s3_object.upload_file(file.tempfile.path, acl: 'public-read') do |progress|
        # Progress tracking logic here
        # puts "Uploaded #{progress.loaded} of #{progress.total} bytes"
      end

      uploaded_file_keys << s3_object.key
    end

    render json: { keys: uploaded_file_keys }
  end
end