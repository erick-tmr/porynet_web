#!/usr/bin/env bash
set -Eeuo pipefail

# Upload the static images under app/assets/images/ to the Cloudflare R2 dev bucket
# (porynet-dev) preserving their relative path as the object key, so the app loads them
# from the r2.dev public URL instead of the Propshaft pipeline. The images are gitignored
# (served from R2, re-derivable from vendor/pokeapi-sprites), so they must be present in
# THIS local checkout for the upload to read. Idempotent: same keys overwrite on re-run.
#
# Runs in the development env (dotenv-free): reads r2.access_key_id / r2.secret_access_key
# from the default Rails credentials and the bucket/endpoint from config.x. Set the R2 API
# token with: bin/rails credentials:edit

cd "$(dirname "$0")/.."

exec bin/rails runner '
  client = Assets::R2Uploader.client(
    access_key_id: Rails.application.credentials.dig(:r2, :access_key_id),
    secret_access_key: Rails.application.credentials.dig(:r2, :secret_access_key),
    endpoint: Rails.application.config.x.r2_endpoint
  )
  keys = Assets::R2Uploader.new(client: client, bucket: Rails.application.config.x.r2_bucket).call
  puts "uploaded #{keys.size} images -> #{Rails.application.config.x.r2_bucket}"
'
