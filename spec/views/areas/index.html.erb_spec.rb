require 'rails_helper'

RSpec.describe 'areas/index', type: :view do
  before do
    assign(:areas, [{ 'key' => '24' }, { 'key' => '25' }])
    assign(:favorites, { 'areas' => ['24'] })
    without_partial_double_verification do
      allow(view).to receive(:current_user).and_return(nil)
    end
  end

  it 'lists each area linking through to its squares' do
    render

    expect(rendered).to include('Areas')
    expect(rendered).to include('Area 24')
    expect(rendered).to include('Area 25')
    expect(rendered).to include(area_squares_path('24'))
  end

  it 'no longer renders the placeholder Recent section' do
    render

    expect(rendered).not_to include('Recent')
    expect(rendered).not_to include('default.jpg') # the placeholder image is gone
  end

  it 'shows favorited areas in the Favorites frame' do
    render

    expect(rendered).to include('Favorites')
  end
end
