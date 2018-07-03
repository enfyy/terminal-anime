class CreateShows < ActiveRecord::Migration[5.2]
  def change
    create_table :shows do |t|
      t.integer :hs_id,       null:false, unique: true
      t.string  :title,       null:false
      t.string  :href ,       null:false, unique: true
      t.integer :ep_count,    null:false
      t.string  :release_day
      t.date    :last_release
      t.timestamps
    end
  end
end
