class ProjectsController < ApplicationController
  # Project management runs at the apex host (no project subdomain), so it must
  # not require a current project database.
  skip_before_action :set_db
  skip_before_action :check_editing_mode
  before_action :require_superuser

  def index
    @projects = Project.all.map do |key|
      {
        key: key,
        name: Project.display_name(key),
        description: Project.description(key),
        cover_url: Project.cover_photo_url(key, :thumb)
      }
    end
  end

  def new; end

  def edit
    load_project
  end

  def create
    key = Project.create!(
      params[:key],
      name: params[:name],
      description: params[:description]
    )
    # Cover upload is best-effort: the project is already provisioned, so a
    # failed/absent upload (e.g. S3 not configured in dev) must not roll it back.
    if cover_param.present?
      begin
        Project.update_metadata(key, cover_photo: upload_cover(key))
      rescue StandardError => e
        flash[:warning] = "Project created, but the cover photo failed to upload: #{e.message}"
      end
    end
    flash[:success] = "Project '#{key}' created."
    redirect_to projects_path
  rescue ArgumentError => e
    flash.now[:error] = e.message
    render :new, status: :unprocessable_entity
  rescue StandardError => e
    flash.now[:error] = "Could not create project: #{e.message}"
    render :new, status: :unprocessable_entity
  end

  def update
    key = params[:id]
    cover_key = cover_param.present? ? upload_cover(key) : nil
    Project.update_metadata(
      key,
      name: params[:name],
      description: params[:description],
      cover_photo: cover_key
    )
    flash[:success] = 'Project updated.'
    redirect_to projects_path
  rescue StandardError => e
    flash.now[:error] = "Could not update project: #{e.message}"
    load_project(key)
    render :edit, status: :unprocessable_entity
  end

  private

  def load_project(key = params[:id])
    @key = key
    @metadata = Project.metadata(key)
    @cover_url = Project.cover_photo_url(key)
  end

  def cover_param
    params[:cover]
  end

  # Upload the cover image to the shared bucket (public-read) and return its key.
  def upload_cover(key)
    bucket = Rails.application.config.try(:s3_bucket)
    raise 'Object storage is not configured in this environment' if bucket.nil?

    file = cover_param
    object_key = Project.cover_photo_object_key(key, file.original_filename)
    bucket.object(object_key).upload_file(file.tempfile.path, acl: 'public-read')
    object_key
  end
end
