require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe '#oauth_start_url' do
    it 'starts the handshake on the apex domain, carrying the current host as origin' do
      request.host = 'balua.opendig.org'

      url = helper.oauth_start_url('google_oauth2')

      expect(url).to start_with('http://opendig.org/auth/google_oauth2?origin=')
      expect(url).to include(CGI.escape('http://balua.opendig.org/'))
    end

    it 'preserves a non-default port (dev) and the registrable domain' do
      request.host = 'balua.lvh.me'
      request.env['HTTP_HOST'] = 'balua.lvh.me:3000'

      expect(helper.oauth_start_url('developer')).to start_with('http://lvh.me:3000/auth/developer?origin=')
    end
  end

  describe '#input_for' do
    it 'renders an editable select for a munsel_picker (was unhandled -> blank)' do
      field = { 'key' => 'munsel', 'type' => 'munsel_picker', 'values' => ['10YR 5/3', '2.5Y 4/2'] }

      html = helper.input_for(field, '10YR 5/3', 'earth_description')

      expect(html).to include('<select')
      expect(html).to include('name="locus[earth_description][munsel]"')
      expect(html).to include('<option selected="selected" value="10YR 5/3">10YR 5/3</option>')
    end

    it 'falls back to a text field for a missing/unknown type (was rendered nothing)' do
      html = helper.input_for({ 'key' => 'foo', 'type' => nil }, 'bar', 'earth_description')

      expect(html).to include('type="text"')
      expect(html).to include('name="locus[earth_description][foo]"')
      expect(html).to include('value="bar"')
    end

    it 'renders the searchable swatch widget for a munsell_swatch field' do
      field = { 'key' => 'munsell', 'type' => 'munsell_swatch' }

      html = helper.input_for(field, '10YR 5/3', 'find')

      expect(html).to include('data-controller="munsell-picker"')
      # hidden field carries the stored notation under the same name the plain
      # picker used, so saving is unchanged
      expect(html).to include('type="hidden"')
      expect(html).to include('name="locus[find][munsell]"')
      expect(html).to include('value="10YR 5/3"')
      # the full colour set is handed to the Stimulus controller as a value
      expect(html).to include('data-munsell-picker-colors-value')
      # current selection shows its real swatch colour
      expect(html).to match(/munsell-picker__swatch.*background-color:#[0-9a-f]{6}/)
    end

    it 'renders a repeatable colour field (multi) with an array name and Add button' do
      field = { 'key' => 'munsell', 'type' => 'munsell_swatch', 'label' => 'Color', 'multi' => true }

      html = helper.input_for(field, ['10YR 5/3', '7.5YR 4/4'], 'find')

      expect(html).to include('data-controller="repeatable"')
      expect(html).to include('repeatable-target="template"')
      expect(html).to include('name="locus[find][munsell][]"')
      expect(html).to include('+ Add color')
      # one picker per stored value, plus the (inert) template entry
      expect(html.scan('munsell-picker__trigger').size).to eq(3)
    end

    it 'renders a repeatable decoration field (multi) with array-named selects' do
      helper.instance_variable_set(:@descriptions, { 'lookups' => { 'decoration' => ['', 'Painted', 'Incised'] } })
      field = { 'key' => 'decoration', 'type' => 'picker', 'label' => 'Decoration',
                'multi' => true, 'values' => { 'from' => 'decoration' } }

      html = helper.input_for(field, 'Painted', 'find')

      expect(html).to include('data-controller="repeatable"')
      expect(html).to include('name="locus[find][decoration][]"')
      expect(html).to include('+ Add decoration')
    end
  end

  describe '#output' do
    it 'shows a colour swatch next to a known Munsell notation' do
      html = helper.output('10YR 5/3', 'munsell_swatch')

      expect(html).to include('10YR 5/3')
      expect(html).to match(/background-color:#[0-9a-f]{6}/)
    end

    it 'shows a non-Munsell colour value as text with no swatch' do
      html = helper.output('Brown', 'munsell_swatch')

      expect(html).to include('Brown')
      expect(html).not_to include('background-color')
    end

    it 'renders a swatch per notation for a multi-value colour array' do
      html = helper.output(['10YR 5/3', '2.5YR 4/6'], 'munsell_swatch')

      expect(html).to include('10YR 5/3')
      expect(html).to include('2.5YR 4/6')
      expect(html.scan(/background-color:#[0-9a-f]{6}/).size).to eq(2)
    end

    it 'joins a multi-value plain field (e.g. Decoration) with commas' do
      expect(helper.output(%w[Painted Incised], 'picker')).to eq('Painted, Incised')
    end
  end
end
