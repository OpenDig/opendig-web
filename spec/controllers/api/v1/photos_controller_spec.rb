require 'rails_helper'

RSpec.describe Api::V1::PhotosController, type: :controller do
  let(:users) { load_user_fixtures }
  let(:s3_object) { instance_double(Aws::S3::Object, upload_file: true) }
  let(:bucket) { instance_double(Aws::S3::Bucket, object: s3_object) }

  before do
    allow(Project).to receive(:all).and_return(['opendig'])
    allow(controller).to receive(:s3_bucket).and_return(bucket)
    allow(Photo).to receive(:url_for_key).and_return('https://img.test/x/preview')
  end

  def image_upload(name = 'shot.jpg', type = 'image/jpeg')
    file = Tempfile.new(['shot', '.jpg'])
    file.binmode
    file.write('fake-image-bytes')
    file.rewind
    Rack::Test::UploadedFile.new(file.path, type, original_filename: name)
  end

  def authenticate_as(user)
    device, token = Device.create_for(user)
    request.headers['Authorization'] = "Bearer #{token}"
    device
  end

  describe 'POST create' do
    it 'uploads a user/field photo and returns the server-built key' do
      device = authenticate_as(users[:dig_director])
      expect(s3_object).to receive(:upload_file)
      post :create, params: { project: 'opendig', kind: 'user', locus: '9.5.001',
                              taken_at: '2026-06-29T10:00:00Z', file: image_upload }

      body = response.parsed_body
      expect(response).to have_http_status(:created)
      expect(body['key']).to match(%r{\Aopendig/user_photos/9_5_001-dig_director_example_com-\d{8}T\d{6}Z-[0-9a-f]{6}\.jpg\z})
    ensure
      device&.revoke!
    end

    it 'builds a daily photo key from the number' do
      device = authenticate_as(users[:dig_director])
      post :create, params: { project: 'opendig', kind: 'daily', number: '12345', file: image_upload }

      body = response.parsed_body
      expect(response).to have_http_status(:created)
      expect(body['key']).to eq('opendig/daily_photos/12345.jpg')
    ensure
      device&.revoke!
    end

    it 'rejects a non-image upload' do
      device = authenticate_as(users[:dig_director])
      post :create, params: { project: 'opendig', file: image_upload('notes.txt', 'text/plain') }
      expect(response).to have_http_status(:unprocessable_entity)
    ensure
      device&.revoke!
    end

    it 'rejects a project the device user has no role on' do
      # dig_director has a role on 'opendig' only, not on 'other_project'.
      device = authenticate_as(users[:dig_director])
      post :create, params: { project: 'other_project', kind: 'user', locus: '9.5.001', file: image_upload }
      expect(response).to have_http_status(:unauthorized)
    ensure
      device&.revoke!
    end

    it 'rejects a missing token' do
      post :create, params: { project: 'opendig', file: image_upload }
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
