#!/usr/bin/env bash
set -Eeuo pipefail

# Upload the static images under app/assets/images/ to the Cloudflare R2 dev bucket
# (porynet-dev) preserving their relative path as the object key, so the app loads them
# from the r2.dev public URL instead of the Propshaft pipeline. The images are gitignored
# (served from R2, re-derivable from vendor/pokeapi-sprites), so they must be present in
# THIS local checkout for the upload to read.
#
# Incremental by default: a gitignored fingerprint cache (.r2-upload-cache.json) records the
# content digest of each image last uploaded, so a re-run sends only the ones whose bytes
# changed. Because the renderer is deterministic, regenerating everything but editing one map
# re-uploads just that map. Pass --force to ignore the cache and re-send every image.
#
# Runs in the development env (dotenv-free): reads r2.access_key_id / r2.secret_access_key
# from the default Rails credentials and the bucket/endpoint from config.x. Set the R2 API
# token with: bin/rails credentials:edit

cd "$(dirname "$0")/.."

exec bin/rails runner '
  force = ARGV.include?("--force")
  bucket = Rails.application.config.x.r2_bucket
  client = Assets::R2Uploader.client(
    access_key_id: Rails.application.credentials.dig(:r2, :access_key_id),
    secret_access_key: Rails.application.credentials.dig(:r2, :secret_access_key),
    endpoint: Rails.application.config.x.r2_endpoint
  )
  keys = Assets::R2Uploader.new(client: client, bucket: bucket).call(force: force)
  puts keys.empty? ? "no changed images to upload -> #{bucket}" : "uploaded #{keys.size} changed images -> #{bucket}"
' "$@"
