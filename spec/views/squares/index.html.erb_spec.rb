require 'rails_helper'

RSpec.describe 'squares/index', type: :view do
  before do
    assign(:area, '24')
    assign(:squares, %w[1 2])
    assign(:favorites, { 'squares' => ['24/1'] })
    without_partial_double_verification do
      allow(view).to receive(:current_user).and_return(nil)
    end
  end

  it 'lists each square linking through to its loci' do
    render

    expect(rendered).to include('Squares')
    expect(rendered).to include('Square 1')
    expect(rendered).to include('Square 2')
    expect(rendered).to include(area_square_loci_path('24', '1'))
  end

  it 'no longer renders the placeholder Recent section' do
    render

    expect(rendered).not_to include('Recent')
    expect(rendered).not_to include('default.jpg')
  end

  it 'shows area-scoped favorited squares in the Favorites frame' do
    render

    expect(rendered).to include('Favorites')
  end
end
