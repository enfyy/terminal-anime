class CreateWatchlists < ActiveRecord::Migration[5.2]
  def change
    create_table :watchlists do |t|
      t.string :resolution_pref, null: false
      t.integer :last_ep,        null: false
      t.references :show,  null: false
      t.timestamps
    end
  end
end
