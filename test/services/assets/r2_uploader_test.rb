require "test_helper"
require "tmpdir"

class Assets::R2UploaderTest < ActiveSupport::TestCase
  class FakeClient
    attr_reader :calls

    def initialize
      @calls = []
    end

    def put_object(**args)
      @calls << args
    end
  end

  test "#call uploads every png under root keyed by relative path and returns the keys" do
    Dir.mktmpdir do |dir|
      root = Pathname(dir)
      (root / "pokemon" / "yellow").mkpath
      File.binwrite(root / "porygon.png", "A")
      File.binwrite(root / "pokemon" / "yellow" / "025.png", "B")

      client = FakeClient.new
      keys = Assets::R2Uploader.new(client: client, bucket: "porynet-dev", root: root).call

      assert_equal [ "pokemon/yellow/025.png", "porygon.png" ], keys
      assert_equal 2, client.calls.size

      nested = client.calls.first
      assert_equal "porynet-dev", nested[:bucket]
      assert_equal "pokemon/yellow/025.png", nested[:key]
      assert_equal "B", nested[:body]
      assert_equal "image/png", nested[:content_type]
      assert_equal "public, max-age=31536000, immutable", nested[:cache_control]
    end
  end

  def uploader(client, root)
    Assets::R2Uploader.new(client: client, bucket: "porynet-dev", root: root)
  end

  test "#call skips images whose bytes are unchanged since the last upload" do
    Dir.mktmpdir do |dir|
      root = Pathname(dir)
      File.binwrite(root / "a.png", "A")
      File.binwrite(root / "b.png", "B")
      uploader(FakeClient.new, root).call # first run seeds the fingerprint cache

      client = FakeClient.new
      keys = uploader(client, root).call

      assert_empty keys
      assert_empty client.calls
    end
  end

  test "#call re-uploads only the image whose bytes changed" do
    Dir.mktmpdir do |dir|
      root = Pathname(dir)
      File.binwrite(root / "a.png", "A")
      File.binwrite(root / "b.png", "B")
      uploader(FakeClient.new, root).call

      File.binwrite(root / "b.png", "CHANGED")
      client = FakeClient.new
      keys = uploader(client, root).call

      assert_equal [ "b.png" ], keys
      assert_equal [ "b.png" ], client.calls.map { |c| c[:key] }
    end
  end

  test "#call with force re-sends every image, ignoring the cache" do
    Dir.mktmpdir do |dir|
      root = Pathname(dir)
      File.binwrite(root / "a.png", "A")
      uploader(FakeClient.new, root).call

      client = FakeClient.new
      keys = uploader(client, root).call(force: true)

      assert_equal [ "a.png" ], keys
      assert_equal 1, client.calls.size
    end
  end

  test "#prime_cache records the images on disk without uploading anything" do
    Dir.mktmpdir do |dir|
      root = Pathname(dir)
      File.binwrite(root / "a.png", "A")
      client = FakeClient.new

      keys = uploader(client, root).prime_cache

      assert_equal [ "a.png" ], keys
      assert_empty client.calls, "prime_cache seeds the fingerprint, it does not upload"

      followup = FakeClient.new
      assert_empty uploader(followup, root).call
      assert_empty followup.calls
    end
  end

  test ".client builds an Aws::S3::Client pointed at the R2 endpoint" do
    client = Assets::R2Uploader.client(
      access_key_id: "AKID",
      secret_access_key: "SECRET",
      endpoint: "https://acct.r2.cloudflarestorage.com"
    )

    assert_kind_of Aws::S3::Client, client
    assert_equal "auto", client.config.region
    assert_includes client.config.endpoint.to_s, "acct.r2.cloudflarestorage.com"
    assert client.config.force_path_style
  end
end
