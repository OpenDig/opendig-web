module Api
  module V1
    # Pending convention-named photos for a square, for the mobile app. Reuses
    # the same bucket listing + matching as the web (BulkPhoto), scoped to the
    # device user's project.
    class PhotosController < Api::BaseController
      before_action :authenticate_device!

      # Cap device uploads so a bad/huge request can't exhaust memory or disk.
      MAX_UPLOAD_BYTES = 30 * 1024 * 1024

      # POST /api/v1/photos  (multipart/form-data)
      #   file       the image (required)
      #   project    project key (required; device must have a role on it)
      #   kind       'user' (default) or 'daily'
      #   locus      locus identifier, for the user-photo key (kind=user)
      #   taken_at   ISO8601 capture time (kind=user; defaults to now)
      #   number     official photo number (kind=daily)
      #
      # Uploads the image to the project's bucket and returns the object key. The
      # server builds the key from the project's own prefixes, so a device can
      # only ever write within its project — no S3 credentials reach the device.
      def create
        project = params[:project].to_s
        return render_unauthorized unless device_can_access?(project)

        file = params[:file]
        return render(json: { error: 'file is required' }, status: :unprocessable_entity) if file.blank?

        content_type = file.content_type.to_s
        return render(json: { error: 'unsupported file type' }, status: :unprocessable_entity) unless content_type.start_with?('image/')
        return render(json: { error: 'file too large' }, status: :unprocessable_entity) if file.tempfile.size > MAX_UPLOAD_BYTES

        return render(json: { error: 'storage not configured' }, status: :service_unavailable) if s3_bucket.nil?

        key = CouchDB.with_project(project) do
          object_key = build_object_key(file)
          s3_bucket.object(object_key).upload_file(file.tempfile.path, acl: 'public-read', content_type: content_type)
          object_key
        end

        render json: { key: key, url: Photo.url_for_key(key, :preview) }, status: :created
      rescue StandardError => e
        Rails.logger.error("Device photo upload failed: #{e.class}: #{e.message}")
        render json: { error: 'upload failed' }, status: :bad_gateway
      end

      # GET /api/v1/photos/pending?project=<key>&area=<a>&square=<s>
      def pending
        project = params[:project].to_s
        area = params[:area].to_s
        square = params[:square].to_s

        return render_unauthorized unless device_can_access?(project)
        return render(json: { error: 'area and square are required' }, status: :unprocessable_entity) if area.blank? || square.blank?

        photos = CouchDB.with_project(project) do
          BulkPhoto.pending_for_square(area, square).map do |entry|
            {
              key: entry.key,
              filename: entry.filename,
              subject: entry.name.subject,
              date: entry.name.date,
              # thumb_url is bumped to the crisp `preview` size so existing app
              # builds (which read thumb_url) get sharp images with no rebuild.
              thumb_url: Photo.url_for_key(entry.key, :preview),
              preview_url: Photo.url_for_key(entry.key, :preview),
              url: Photo.url_for_key(entry.key, :medium),
              full_url: Photo.url_for_key(entry.key, :original)
            }
          end
        end

        render json: { photos: photos }
      end

      private

      # The configured project bucket (nil until the s3 initializer has run,
      # e.g. when credentials are absent). Wrapped in a method so it's a single
      # seam to stub in tests.
      def s3_bucket
        Rails.application.config.try(:s3_bucket)
      end

      # Build the object key for an upload. Must run inside CouchDB.with_project
      # so ProjectStorage resolves the right prefixes. For official daily photos
      # the key is <daily_photos>/<number>.<ext>; for user/field photos the
      # uploader is the authenticated device user (server-trusted, never client
      # input).
      def build_object_key(file)
        ext = file_extension(file)
        if params[:kind].to_s == 'daily'
          number = ProjectStorage.key_slug(params[:number])
          raise 'number is required for a daily photo' if number.blank?

          "#{ProjectStorage.daily_photos_prefix}/#{number}.#{ext}"
        else
          ProjectStorage.user_photo_key(
            locus: params[:locus].to_s,
            user_id: @current_user.email.presence || 'device',
            taken_at: parsed_taken_at,
            ext: ext
          )
        end
      end

      def file_extension(file)
        from_name = File.extname(file.original_filename.to_s).delete_prefix('.').downcase
        return from_name if from_name.present?

        # Fall back to the content subtype (image/jpeg -> jpg).
        subtype = content_subtype(file)
        subtype == 'jpeg' ? 'jpg' : (subtype.presence || 'jpg')
      end

      def content_subtype(file)
        file.content_type.to_s.split('/').last.to_s.downcase
      end

      def parsed_taken_at
        Time.zone.parse(params[:taken_at].to_s) || Time.current
      rescue ArgumentError, TypeError
        Time.current
      end

      def device_can_access?(project)
        return false if project.blank?

        @current_user&.superuser? || @current_user&.roles&.key?(project)
      end
    end
  end
end
