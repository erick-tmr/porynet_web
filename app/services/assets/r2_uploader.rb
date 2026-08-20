require "digest"
require "json"

module Assets
  class R2Uploader
    CONTENT_TYPE = "image/png".freeze
    # Most keys hold bytes that never change once written: a ripped sprite, a badge, a piece of
    # hand-prepared art. Those are worth a year and never asking again.
    IMMUTABLE_CACHE = "public, max-age=31536000, immutable".freeze

    # The generated tree is the exception, and it is the one a reader watches: `build.py` rewrites
    # a map or a scene in place under the key it already had. `immutable` promises what that file
    # does not keep, and a browser takes the promise literally, holding the old picture through a
    # reload and any amount of regenerating. R2 sends a strong ETag, so asking about one of these
    # costs a 304 and no body.
    REGENERATED_PREFIX = "walkthrough/yellow/".freeze
    REGENERATED_CACHE = "public, max-age=0, must-revalidate".freeze

    def self.cache_control(key)
      key.to_s.start_with?(REGENERATED_PREFIX) ? REGENERATED_CACHE : IMMUTABLE_CACHE
    end
    # A gitignored fingerprint file next to the images: object key -> content digest of what was
    # last uploaded. A re-run sends only the images whose bytes actually changed, which matters
    # because the renderer is deterministic: regenerating an unchanged map leaves byte-identical
    # PNGs, so their digests (and R2) stay put and the upload skips them.
    CACHE_FILE = ".r2-upload-cache.json".freeze

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
      @cache_path = root.join(CACHE_FILE)
    end

    # Upload every image whose content digest differs from the last upload's, then rewrite the
    # cache to the current set. `force: true` ignores the cache and re-sends everything (a fresh
    # bucket, or when you want to be certain). Returns the keys actually uploaded.
    def call(force: false)
      current = digests
      uploaded = upload_changed(current, force ? {} : load_cache)
      write_cache(current)
      uploaded
    end

    # Record the images on disk as already uploaded without sending anything, to seed the cache
    # when the bucket is known to match this checkout (e.g. right after a full upload).
    def prime_cache
      current = digests
      write_cache(current)
      current.keys
    end

    private

    def upload_changed(current, previous)
      current.filter_map do |key, digest|
        next if previous[key] == digest

        put(key, @root.join(key))
        key
      end
    end

    def put(key, path)
      @client.put_object(
        bucket: @bucket,
        key: key,
        body: File.binread(path),
        content_type: CONTENT_TYPE,
        cache_control: self.class.cache_control(key)
      )
    end

    def digests
      Dir.glob(@root.join("**/*.png")).sort.to_h do |path|
        [ Pathname(path).relative_path_from(@root).to_s, Digest::MD5.file(path).hexdigest ]
      end
    end

    def load_cache
      return {} unless File.exist?(@cache_path)

      JSON.parse(File.read(@cache_path))
    end

    def write_cache(current)
      File.write(@cache_path, JSON.pretty_generate(current))
    end
  end
end
