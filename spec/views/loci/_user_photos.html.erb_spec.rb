require 'rails_helper'

RSpec.describe 'loci/_user_photos', type: :view do
  let(:field_photo) do
    { 'key' => 'balua/user_photos/L1-u8-20260619T143355Z-3b9c.jpg',
      'user' => 'u8', 'user_name' => 'Field Lead',
      'taken_at' => '2026-06-19T14:33:55Z', 'subject' => 'north baulk' }
  end

  before do
    # Avoid building real imgproxy URLs (needs S3 config); assert on the key/style.
    allow(Photo).to receive(:url_for_key) { |key, style| "https://img.test/#{key}/#{style}" }
  end

  it 'renders field photos in a distinct unofficial section with attribution' do
    assign(:locus, { 'user_photos' => [field_photo] })

    render partial: 'loci/user_photos'

    expect(rendered).to include('Field Photos')
    expect(rendered).to match(/Unofficial/i)
    expect(rendered).to include('Field Lead')   # uploader attribution
    expect(rendered).to include('north baulk')  # subject
    expect(rendered).to include('19 Jun, 2026') # read_date(taken_at)
    expect(rendered).to include('https://img.test/balua/user_photos/L1-u8-20260619T143355Z-3b9c.jpg/thumb')
  end

  it 'falls back to the user id when no display name is recorded' do
    assign(:locus, {
             'user_photos' => [
               { 'key' => 'balua/user_photos/x.jpg', 'user' => 'u8', 'taken_at' => '2026-06-19T00:00:00Z' }
             ]
           })

    render partial: 'loci/user_photos'

    expect(rendered).to include('u8')
  end
end
