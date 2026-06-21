class ApplicationController < ActionController::Base
  before_action :resolve_project
  before_action :set_db, :set_descriptions, :set_edit_mode
  before_action :check_editing_mode, only: %i[new edit create update destroy]

  helper_method :current_user, :user_signed_in?, :require_authentication, :user_role?, :require_role,
                :require_superuser, :require_dig_director, :require_area_supervisor, :require_square_supervisor,
                :require_registrar_read, :require_registrar_write, :require_manage_users, :current_dig, :current_project

  private

  # Resolve the project ("dig") from the request subdomain (balua.opendig.org ->
  # "balua") and make it the current CouchDB project for this request. The apex
  # host (no subdomain) shows the OpenDig landing page; an unknown subdomain 404s.
  def resolve_project
    key = request.subdomains.reject { |s| s == 'www' }.last
    @project = nil
    CouchDB.current_project = nil

    if key.blank?
      # The apex host normally shows the landing page, but superuser project
      # administration also lives at the apex (it spans all projects).
      return if controller_name == 'projects'

      render 'shared/landing', layout: false
    elsif Project.exists?(key)
      @project = key
      CouchDB.current_project = key
    else
      render 'shared/unknown_project', layout: false, status: :not_found
    end
  end

  def set_locus
    @area = params[:area_id]
    @square = params[:square_id]
    @locus_code = params[:id]
    @locus = @db.view('opendig/locus', key: [@area, @square, @locus_code])['rows']&.first&.dig('value')
  end

  def set_db
    @db = CouchDB.main_db
    @auth_db = CouchDB.auth_db
  end

  def set_descriptions
    @descriptions = Rails.application.config.descriptions
  end

  def set_edit_mode
    @editing_enabled = ENV['EDITING_ENABLED'] || false
  end

  def check_editing_mode
    return if @editing_enabled

    flash[:error] = 'Editing is disabled'
    redirect_to request.referer
  end

  def toggle_favorite(category, resource_id)
    load_favorites

    @favorited = favorited?(category => resource_id)
    if @favorited
      remove_favorite category => resource_id
    else
      add_favorite category => resource_id
    end
    @favorited = !@favorited # Toggle before responding to ensure the view reflects the new state
  end

  def favorite_params
    params.require(:favorite).permit(:category, :resource_id)
  end

  def load_favorites
    @favorites = JSON.parse(cookies.permanent[:favorites] || "{}")
  end

  def save_favorites(favorites = @favorites || {})
    cookies.permanent[:favorites] = favorites.to_json
    load_favorites
  end

  def add_favorite(**categories)
    Rails.logger.info "  Adding favorite: #{categories.inspect}"

    categories.each do |category, resource_id|
      @favorites[category.to_s] ||= []
      @favorites[category.to_s] << resource_id unless @favorites[category.to_s].include?(resource_id)
    end

    save_favorites
  end

  def remove_favorite(**categories)
    Rails.logger.info "  Removing favorite: #{categories.inspect}"

    categories.each do |category, resource_id|
      @favorites[category.to_s] ||= []
      @favorites[category.to_s].delete(resource_id)
    end

    save_favorites
  end

  def favorited?(**categories)
    categories.all? do |category, resource_id|
      @favorites[category.to_s]&.include?(resource_id.to_s)
    end
  end

  def user_signed_in?
    !!current_user
  end

  def current_user
    return nil unless session[:user_id]

    # Cache current user so we aren't looking them up multiple times per request.
    # Scope their role lookups to the project resolved for this request.
    @current_user ||= User.find(session[:user_id])&.tap { |u| u.current_dig = @project }
  end

  def require_authentication
    return if user_signed_in?

    flash[:error] = "You must be logged in to access this section"
    redirect_to root_path
    false
  end

  def user_role?(role, scope: nil)
    role = role.to_s
    scope = scope.is_a?(Array) ? scope.map(&:to_s) : scope.to_s if scope
    return true if role.to_s == 'viewer'
    return false unless user_signed_in?
    return false unless current_user.role_at_least? role
    if scope && current_user.role == role
      return current_user.role_scopes.include?(scope)
    elsif scope
      # User has a higher role so we need to check if they have access to a larger scope
      return current_user.role_scopes.any? do |user_scope|
        case [scope.class, user_scope.class]
        when [String, String]
          # scope is an area and user_scope is a dig
          current_dig == user_scope
        when [Array, String]
          # scope is a square and user_scope is either a dig or an area
          scope.first.start_with?(user_scope) || current_dig == user_scope
        else
          false
        end
      end
    end

    true
  end

  def require_role(role, scope: nil)
    require_authentication
    return if performed? # Don't check role if authentication check failed

    role = role.to_s
    scope = scope.is_a?(Array) ? scope.map(&:to_s) : scope.to_s if scope
    unless current_user.role_at_least? role
      flash[:error] = "You must be a(n) #{role.humanize.downcase} to access this section"
      redirect_to root_path
      return false
    end

    if scope && current_user.role == role && !current_user.role_scopes.include?(scope)
      flash[:error] = "You do not have access to this section"
      redirect_to root_path
      return false
    end

    true
  end

  def require_superuser = require_role :superuser

  def require_dig_director = require_role :dig_director, scope: current_dig

  # Excavation-data edit gates. These use the capability predicate (which excludes
  # registrars) rather than the linear `require_role`, since a registrar ranks above
  # the supervisors in the role list but must stay read-only on excavation data.
  def require_area_supervisor(area_id)
    require_dig_data_edit(:area_supervisor, area: area_id)
  end

  def require_square_supervisor(square_scope)
    area, square = Array(square_scope)
    require_dig_data_edit(:square_supervisor, area: area, square: square)
  end

  # Registrar tools: everyone in the project may read; registrar/dig_director/superuser may write.
  def require_registrar_read = require_capability(:can_view_registrar?, "view the registrar")

  def require_registrar_write = require_capability(:can_edit_registrar?, "edit the registrar")

  # User role management for the project.
  def require_manage_users = require_capability(:can_manage_roles?, "manage users")

  def require_dig_data_edit(role_label, area:, square: nil)
    require_authentication
    return if performed?

    return true if current_user.can_edit_dig_data?(area: area, square: square)

    flash[:error] = "You must be a(n) #{role_label.to_s.humanize.downcase} to access this section"
    redirect_to root_path
    false
  end

  # Generic capability gate: requires authentication then a boolean predicate on the user.
  def require_capability(predicate, action_description)
    require_authentication
    return if performed?

    return true if current_user.public_send(predicate)

    flash[:error] = "You are not allowed to #{action_description}"
    redirect_to root_path
    false
  end

  # The project ("dig") resolved for this request (set by `resolve_project`).
  # Falls back to the thread-local current project for contexts that bypass the
  # request cycle (e.g. unit tests invoking helpers directly).
  def current_dig = @project || CouchDB.current_project

  alias current_project current_dig
end
