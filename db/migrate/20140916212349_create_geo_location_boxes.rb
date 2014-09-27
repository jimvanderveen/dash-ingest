class CreateGeoLocationBoxes < ActiveRecord::Migration
  def change
    create_table :geo_location_boxes, :options => 'ENGINE=MyISAM' do |t|
      t.string :box
      t.integer :record_id

      t.timestamps
    end
  end
end
