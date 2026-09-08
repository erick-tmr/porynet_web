class CreateSaveFiles < ActiveRecord::Migration[8.1]
  def change
    create_table :save_files do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :game_slug, null: false

      t.timestamps
      t.index [ :user_id, :game_slug ], unique: true
    end

    create_table :walkthrough_marks do |t|
      t.references :save_file, null: false, foreign_key: { on_delete: :cascade }
      t.string :mark_id, null: false, limit: 96
      t.datetime :created_at, null: false

      t.index [ :save_file_id, :mark_id ], unique: true
    end

    create_table :pokemon do |t|
      t.references :save_file, null: false, foreign_key: { on_delete: :cascade }
      t.uuid :tracker, null: false, default: -> { "gen_random_uuid()" }
      t.string :national_dex, null: false, limit: 3
      t.string :origin_context, null: false
      t.string :origin_game_slug
      t.string :nickname

      t.timestamps
      t.index :tracker, unique: true
      t.index [ :save_file_id, :national_dex ]
      t.check_constraint "national_dex ~ '^[0-9]{3}$'", name: "pokemon_national_dex"
    end

    create_table :pokemon_blocks do |t|
      t.references :pokemon, null: false, foreign_key: { on_delete: :cascade }
      t.string :context, null: false
      t.jsonb :payload, null: false, default: {}

      t.timestamps
      t.index [ :pokemon_id, :context ], unique: true
    end
  end
end
