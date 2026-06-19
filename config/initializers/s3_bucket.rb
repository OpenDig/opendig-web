require 'aws-sdk-core'
require 'aws-sdk-s3'
require 'imgproxy'

# Configure the S3-compatible client wherever object storage is available:
# production (Wasabi) and development (minio) both set S3_URL. The test env sets
# neither and stubs config.s3_bucket. We use Wasabi/minio, never plain AWS, so
# the endpoint and region are always explicit.
#
# Fail soft: Aws::S3::Resource.new validates credentials eagerly, so without them
# it raises. A misconfigured/credential-less object store must NOT crash app boot
# -- leave config.s3_bucket unset and let the image helpers fall back to a
# placeholder (see Photo/Find).
if ENV['S3_URL'].present? || Rails.env.production?
  begin
    Aws.config.update(endpoint: ENV['S3_URL'], force_path_style: true) if ENV['S3_URL'].present?
    Aws.config.update(region: ENV.fetch('AWS_REGION', 'us-east-1'))

    s3 = Aws::S3::Resource.new

    # One universal bucket for all projects; project scoping happens in the object
    # key (<project>/finds/..., <project>/daily_photos/..., <project>/user_photos/...).
    Rails.application.config.s3_bucket = s3.bucket(ENV.fetch('S3_BUCKET', 'opendig'))
  rescue StandardError => e
    Rails.logger.warn("S3 object store not configured (#{e.class}: #{e.message}); image features disabled")
  end
end

# imgproxy must sign URLs with the same key/salt the imgproxy server enforces, or
# the server rejects them. When they're absent (e.g. a dev imgproxy with signature
# checking off) the gem emits unsigned /unsafe/ URLs, which that server accepts.
Imgproxy.configure do |config|
  config.endpoint = ENV['IMGPROXY_URL']
  config.key = ENV['IMGPROXY_KEY'] if ENV['IMGPROXY_KEY'].present?
  config.salt = ENV['IMGPROXY_SALT'] if ENV['IMGPROXY_SALT'].present?
end

placeholder = ENV['PLACEHOLDER_URL'] || "https://placehold.jp/1000x1000.jpg?text=No+Image"
