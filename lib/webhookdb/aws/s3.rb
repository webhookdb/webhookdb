# frozen_string_literal: true

require "aws-sdk-s3"
require "httparty"

class Webhookdb::AWS::S3
  attr_reader :client, :presigner

  def initialize
    @client = ::Aws::S3::Client.new
    @presigner = ::Aws::S3::Presigner.new
  end

  # Create or validate existence of S3 object described by +object_hash+
  def create_if_missing(object_hash)
    obj = object_hash.symbolize_keys
    self.ensure_keys_for_upload(obj)

    self.client.put_object(obj) unless self.exists?(obj[:bucket], obj[:key])

    return self.metadata(obj[:bucket], obj[:key])
  end

  # Create or update an S3 object described by +object_hash+, which is a +Hash+.
  # If the object in passed bucket and with the given key already exists,
  # the object will be replaced in place.
  def put(object_hash)
    obj = object_hash.symbolize_keys
    self.ensure_keys_for_upload(obj)

    return self.client.put_object(obj)
  end

  # Checks if the passed +object_hash+ matches the expected format of the Aws::S3.put_object method, per
  # http://docs.aws.amazon.com/sdkforruby/api/Aws/S3/Client.html#put_object-instance_method
  # (minimum required keys for creation are 'bucket', 'key' and 'body')
  protected def ensure_keys_for_upload(object_hash)
    raise ArgumentError, "object_hash must contain keys 'bucket', 'key' and 'body'" unless
      [:bucket, :key, :body].all? { |k| object_hash.key?(k) }
  end

  # Deletes the S3 object located in +bucket_name+ at +key_name+
  # Returns the DeleteObjectOutput as described here:
  # http://docs.aws.amazon.com/sdkforruby/api/Aws/S3/Client.html#delete_object-instance_method
  def delete(bucket_name, key_name)
    return self.client.delete_object(bucket: bucket_name, key: key_name)
  end

  # Obtain metadata about the S3 object located in +bucket_name+ at +key_name+
  # Returns an +Aws::PageableResponse+ struct of metadata about the object,
  # which is an Enumerable Hash-like object.
  def metadata(bucket_name, key_name)
    return self.client.head_object(bucket: bucket_name, key: key_name)
  end

  # Determine whether the S3 object located in +bucket_name+ at +key_name+ exists.
  def exists?(bucket_name, key_name)
    self.client.get_object_acl(bucket: bucket_name, key: key_name)
    return true
  rescue ::Aws::S3::Errors::NoSuchKey
    return false
  end

  # Return a presigned URL with given +bucket_name+ and +key_name+
  # for anonymous downloading of a protected S3 object.
  # Optionally, you can pass an +opts+ hash if you need additional signing options.
  def presigned_get_url(bucket_name, key_name, opts={})
    method = opts.delete(:method) || :get_object
    return self.presigner.presigned_url(method, opts.merge(bucket: bucket_name, key: key_name))
  end

  def presigned_put_url(bucket_name, filename, prefix: "")
    prefix = prefix ? prefix + "/" : ""
    config = Webhookdb::AWS.bucket_configuration_for(bucket_name)
    opts = {
      bucket: bucket_name,
      key: "#{Webhookdb::RACK_ENV}/#{prefix}#{SecureRandom.hex(8)}-#{filename}",
      expires_in: config[:presign_expiration_secs],
      acl: config[:presign_acl],
    }
    return self.presigner.presigned_url(:put_object, opts)
  end

  # Return the body of the S3 object located in +bucket_name+ at +key_name+
  # #get_object returns a StringIO object, so we need to #read it to get the string value
  def get_string(bucket_name, key_name)
    return self.get_stream(bucket_name, key_name).read
  end

  # Return the body of the S3 object located in +bucket_name+ at +key_name+
  # #get_object returns a StringIO object.
  def get_stream(bucket_name, key_name)
    obj = self.client.get_object(bucket: bucket_name, key: key_name)
    return obj[:body]
  end

  def parse_uri(uri)
    uri = URI(uri)
    url = uri.to_s
    parsed_uri = case uri.scheme
      when "s3"
        url.match(%r{s3://(?<bucket>[\w\-]+)/(?<key>[\w\-/]+\.\w+)}i)
      when "http", "https"
        url.match(%r{
          https?://
          (?<bucket>[\w\-]+)\.
          s3\.
          (?<region>[a-z]{2}-[a-z]+-\d+\.)?
          amazonaws\.com/
          (?<key>[\w\-/]+\.\w+)
        }ix)
    end
    return nil if !parsed_uri || !parsed_uri[:bucket] || !parsed_uri[:key]
    return parsed_uri
  end

  # Returns a tuple of the bucket and key name
  # from an HTTP or S3 uri/url in the following format:
  #
  #   s3://bucket-name/key.ext
  #   http://bucket-name.s3.amazonaws.com/key.ext
  #
  def bucket_and_key_from_uri(uri)
    (parsed_uri = self.parse_uri(uri)) or
      raise ArgumentError, "'#{uri}' didn't match pattern: 's3://bucket/key' or 'http://bucket.s3.amazonaws.com/key"

    return parsed_uri[:bucket], parsed_uri[:key]
  end

  # Returns a signed url from an HTTP or S3 uri/url in the following format:
  #
  #   s3://bucket-name/key.ext
  #   http://bucket-name.s3.amazonaws.com/key.ext
  #
  def signed_url_from_uri(uri, signing_options={})
    bucket, key = self.bucket_and_key_from_uri(uri)

    return self.presigned_get_url(bucket, key, signing_options)
  end

  # Upload a file at a URL by downloading it first.
  # In the future, this should generally be done on the client, so we do not want our web servers
  # proxying requests that a client could be doing (usually by uploading to a presigned URL).
  # However, we don't have a pattern yet as of this writing, and it's only for admins now,
  # so let's do it this way. And it is useful for future internal/admin usage, like from the terminal.
  def upload_url(prefix_or_model, bucket, url_or_uri)
    uri = URI(url_or_uri)
    return url_or_uri if self.parse_uri(uri)

    raise "url_or_uri must be an absolute path (start with http(s)://)" if uri.host.nil?

    uri.query = "raw=1" if uri.host.end_with?("dropbox.com") && uri.query.include?("dl=")

    response = HTTParty.get(uri)
    if response.code >= 300
      msg = "GET %s failed: %p %p" % [uri, response.code, response.body]
      raise msg
    end
    image_type = response.headers["Content-Type"]
    image_type ||= MimeMagic.by_path(url_or_uri)
    image_type ||= MimeMagic.by_magic(response.body)
    image_type = image_type.to_s

    prefix = prefix_or_model.is_a?(String) ? prefix_or_model : prefix_or_model.name.sub(/.*::/, "").downcase

    filename = CGI.unescape(uri.path.split("/").last)
    if filename.include?(".")
      basename, _, ext = filename.rpartition(".")
      ext = "." + ext
    else
      basename = filename
      ext = ""
    end
    keypart = basename.downcase.gsub(/[^a-z0-9_-]/, "")

    config = Webhookdb::AWS.bucket_configuration_for(bucket)
    opts = {
      bucket: bucket,
      key: "#{Webhookdb::RACK_ENV}/#{prefix}/#{SecureRandom.hex(8)}-#{keypart}#{ext}",
      acl: config[:presign_acl],
      content_type: image_type,
      body: response.body,
    }
    Webhookdb::AWS.s3.put(opts)
    return "https://#{bucket}.s3.amazonaws.com/#{opts[:key]}"
  end
end
