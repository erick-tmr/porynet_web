module Assets
  class R2Uploader
    CONTENT_TYPE = "image/png".freeze
    CACHE_CONTROL = "public, max-age=31536000, immutable".freeze

    def self.client(access_key_id:, secret_access_key:, endpoint:)
      require "aws-sdk-s3"

      Aws::S3::Client.new(
        access_key_id: access_key_id,
        secret_access_key: secret_access_key,
        endpoint: endpoint,
        region: "auto",
        force_path_style: true
      )
    end

    def initialize(client:, bucket:, root: Rails.root.join("app/assets/images"))
      @client = client
      @bucket = bucket
      @root = root
    end

    def call
      entries.map do |key, path|
        @client.put_object(
          bucket: @bucket,
          key: key,
          body: File.binread(path),
          content_type: CONTENT_TYPE,
          cache_control: CACHE_CONTROL
        )
        key
      end
    end

    private

    def entries
      Dir.glob(@root.join("**/*.png")).sort.map do |path|
        [ Pathname(path).relative_path_from(@root).to_s, path ]
      end
    end
  end
end
