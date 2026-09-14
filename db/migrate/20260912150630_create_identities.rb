class CreateIdentities < ActiveRecord::Migration[8.1]
  def change
    create_table :identities do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :provider, null: false
      t.string :uid, null: false
      t.string :email

      t.timestamps
      t.index [ :provider, :uid ], unique: true
      t.index [ :user_id, :provider ], unique: true
    end
  end
end
