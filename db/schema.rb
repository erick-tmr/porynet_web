# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_08_194555) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "pokemon", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "national_dex", limit: 3, null: false
    t.string "nickname"
    t.string "origin_context", null: false
    t.string "origin_game_slug"
    t.bigint "save_file_id", null: false
    t.uuid "tracker", default: -> { "gen_random_uuid()" }, null: false
    t.datetime "updated_at", null: false
    t.index ["save_file_id", "national_dex"], name: "index_pokemon_on_save_file_id_and_national_dex"
    t.index ["save_file_id"], name: "index_pokemon_on_save_file_id"
    t.index ["tracker"], name: "index_pokemon_on_tracker", unique: true
    t.check_constraint "national_dex::text ~ '^[0-9]{3}$'::text", name: "pokemon_national_dex"
  end

  create_table "pokemon_blocks", force: :cascade do |t|
    t.string "context", null: false
    t.datetime "created_at", null: false
    t.jsonb "payload", default: {}, null: false
    t.bigint "pokemon_id", null: false
    t.datetime "updated_at", null: false
    t.index ["pokemon_id", "context"], name: "index_pokemon_blocks_on_pokemon_id_and_context", unique: true
    t.index ["pokemon_id"], name: "index_pokemon_blocks_on_pokemon_id"
  end

  create_table "save_files", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "game_slug", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "game_slug"], name: "index_save_files_on_user_id_and_game_slug", unique: true
    t.index ["user_id"], name: "index_save_files_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "avatar", default: "red", null: false
    t.datetime "confirmation_sent_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "terms_accepted_at", null: false
    t.string "trainer_name", null: false
    t.string "unconfirmed_email"
    t.datetime "updated_at", null: false
    t.index "lower((trainer_name)::text)", name: "index_users_on_lower_trainer_name", unique: true
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "walkthrough_marks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "mark_id", limit: 96, null: false
    t.bigint "save_file_id", null: false
    t.index ["save_file_id", "mark_id"], name: "index_walkthrough_marks_on_save_file_id_and_mark_id", unique: true
    t.index ["save_file_id"], name: "index_walkthrough_marks_on_save_file_id"
  end

  add_foreign_key "pokemon", "save_files", on_delete: :cascade
  add_foreign_key "pokemon_blocks", "pokemon", on_delete: :cascade
  add_foreign_key "save_files", "users", on_delete: :cascade
  add_foreign_key "walkthrough_marks", "save_files", on_delete: :cascade
end
