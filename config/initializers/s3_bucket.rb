require 'aws-sdk-core'
require 'aws-sdk-s3'
require 'imgproxy'

if Rails.env.production?
  if ENV['S3_URL']
    Aws.config.update(
      endpoint: ENV['S3_URL'],
      force_path_style: true
    )
  end

Aws.config.update(
  region: 'us-east-1'
)

s3 = Aws::S3::Resource.new

bucket_name = "opendig-#{Rails.env}"
Rails.application.config.s3_bucket = s3.bucket(bucket_name)

Imgproxy.configure do |config|
  config.endpoint = ENV['IMGPROXY_URL']
end

Rails.application.config.placeholder_url =
  ENV['PLACEHOLDER_URL'] || "https://placehold.jp/1000x1000.jpg?text=No+Image"
