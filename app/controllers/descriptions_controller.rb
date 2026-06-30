# Dig-director (and superuser) editor for the project's descriptions config.
# Two modes:
#   - lookups: friendly per-list editor (one value per line) for the lookup
#     value lists (designation, material, …);
#   - raw:     a validated JSON editor for the whole descriptions document.
# Both persist a per-project override via ProjectDescriptions (the static
# defaults stay as a fallback and can be re-inherited via Reset).
class DescriptionsController < ApplicationController
  before_action :require_edit_descriptions

  REQUIRED_KEYS = %w[lookups description_types].freeze

  def edit
    @effective = ProjectDescriptions.effective(current_project)
    @lookups = (@effective['lookups'] || {}).sort.to_h
    @version = ProjectDescriptions.version(current_project)
    @raw_json = JSON.pretty_generate(@effective)
  end

  def update
    case params[:mode]
    when 'raw'
      update_raw
    else
      update_lookups
    end
  end

  def destroy
    ProjectDescriptions.reset(current_project)
    redirect_to edit_descriptions_path, notice: 'Descriptions reset to the defaults.'
  end

  private

  # Friendly lookup editor: params[:lookups] = { name => "val1\nval2\n…" }.
  # Merges the edited lookups into the existing override so any raw-mode edits to
  # other sections are preserved.
  def update_lookups
    edited = (params[:lookups] || {}).to_unsafe_h.transform_values do |text|
      text.to_s.split("\n").map(&:strip).compact_blank
    end
    override = ProjectDescriptions.override(current_project).deep_dup
    override['lookups'] = (override['lookups'] || {}).merge(edited)
    ProjectDescriptions.save(current_project, override)
    redirect_to edit_descriptions_path, notice: 'Lookup lists updated.'
  end

  # Advanced: replace the whole descriptions document from validated JSON.
  def update_raw
    parsed = JSON.parse(params[:raw_json].to_s)
    unless parsed.is_a?(Hash) && REQUIRED_KEYS.all? { |k| parsed.key?(k) }
      flash.now[:error] = "Invalid descriptions: must be a JSON object including #{REQUIRED_KEYS.join(', ')}."
      return render_edit_with(parsed_raw: params[:raw_json])
    end

    ProjectDescriptions.save(current_project, parsed)
    redirect_to edit_descriptions_path, notice: 'Descriptions updated from JSON.'
  rescue JSON::ParserError => e
    flash.now[:error] = "Invalid JSON: #{e.message}"
    render_edit_with(parsed_raw: params[:raw_json])
  end

  def render_edit_with(parsed_raw:)
    @effective = ProjectDescriptions.effective(current_project)
    @lookups = (@effective['lookups'] || {}).sort.to_h
    @version = ProjectDescriptions.version(current_project)
    @raw_json = parsed_raw
    render :edit, status: :unprocessable_entity
  end
end
