module Api
  module V1
    # Pending convention-named photos for a square, for the mobile app. Reuses
    # the same bucket listing + matching as the web (BulkPhoto), scoped to the
    # device user's project.
    class PhotosController < Api::BaseController
      before_action :authenticate_device!

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
              thumb_url: Photo.url_for_key(entry.key, :thumb),
              url: Photo.url_for_key(entry.key, :medium)
            }
          end
        end

        render json: { photos: photos }
      end

      private

      def device_can_access?(project)
        return false if project.blank?

        @current_user&.superuser? || @current_user&.roles&.key?(project)
      end
    end
  end
end
