class CreateDomainsAndCompetencies < ActiveRecord::Migration[8.0]
  def change
    create_table :domains do |t|
      t.string :name, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :domains, :name, unique: true
    add_index :domains, :position

    create_table :competencies do |t|
      t.references :domain, null: false, foreign_key: true
      t.string :title, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :competencies, :title, unique: true
    add_index :competencies, [ :domain_id, :position ]
  end
end
