class AddTrainerToSaveFilesAndPokemon < ActiveRecord::Migration[8.1]
  def change
    change_table :save_files, bulk: true do |t|
      t.string :ot_name, limit: 12
      t.bigint :ot_id32
    end

    change_table :pokemon, bulk: true do |t|
      t.string :ot_name, limit: 12
      t.bigint :ot_id32
    end

    add_check_constraint :save_files, "ot_id32 BETWEEN 0 AND 4294967295", name: "save_files_ot_id32"
    add_check_constraint :pokemon, "ot_id32 BETWEEN 0 AND 4294967295", name: "pokemon_ot_id32"
  end
end
