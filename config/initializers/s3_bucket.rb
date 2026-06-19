require 'aws-sdk-core'
require 'aws-sdk-s3'
require 'imgproxy'

if Rails.env.production?
  # We use Wasabi (S3-compatible), so the endpoint and region must be explicit --
  # never assume AWS. S3_URL is the Wasabi endpoint (e.g.
  # https://s3.<region>.wasabisys.com); AWS_REGION must match it.
  if ENV['S3_URL']
    Aws.config.update(
      endpoint: ENV['S3_URL'],
      force_path_style: true
    )
  end

  Aws.config.update(
    region: ENV.fetch('AWS_REGION', 'us-east-1')
  )

  s3 = Aws::S3::Resource.new

  # One universal bucket for all projects; project scoping happens in the object
  # key (<project>/artifacts/..., <project>/daily_photos/...). Dev and prod are
  # separated by endpoint (minio vs. real S3), so the literal name is safe.
  bucket_name = ENV.fetch('S3_BUCKET', 'opendig')
  Rails.application.config.s3_bucket = s3.bucket(bucket_name)
end

Imgproxy.configure do |config|
  config.endpoint = ENV['IMGPROXY_URL']
end

placeholder = ENV['PLACEHOLDER_URL'] || "https://placehold.jp/1000x1000.jpg?text=No+Image"
