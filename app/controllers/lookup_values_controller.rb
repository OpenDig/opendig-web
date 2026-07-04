# Inline add/delete of values for the small, user-managed pick lists surfaced on
# the registrar find form (Decoration, and custom Colours on top of the Munsell
# book). Persists to the project's descriptions override via ProjectDescriptions,
# so an added value is shared across the project and sticks.
#
# Only an allowlisted set of lookups may be edited this way — arbitrary lookup
# mutation stays behind the full Descriptions editor (require_edit_descriptions).
class LookupValuesController < ApplicationController
  before_action :require_registrar_write

  # Lookups a registrar may extend/prune from the find form.
  MANAGEABLE = %w[decoration custom_colors].freeze

  def create
    return head(:unprocessable_entity) unless MANAGEABLE.include?(params[:lookup])

    ProjectDescriptions.add_lookup_value(current_project, params[:lookup], params[:value])
    respond(params[:lookup])
  end

  def destroy
    return head(:unprocessable_entity) unless MANAGEABLE.include?(params[:lookup])

    ProjectDescriptions.remove_lookup_value(current_project, params[:lookup], params[:value])
    respond(params[:lookup])
  end

  private

  def respond(lookup)
    values = ProjectDescriptions.lookup_list(current_project, lookup)
    respond_to do |format|
      format.json { render json: { lookup: lookup, values: values } }
      format.html { redirect_back fallback_location: registrar_index_path } # graceful no-JS fallback
    end
  end
end
