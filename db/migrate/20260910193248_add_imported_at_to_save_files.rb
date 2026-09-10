class AddImportedAtToSaveFiles < ActiveRecord::Migration[8.1]
  def change
    add_column :save_files, :imported_at, :datetime
  end
end
