class CreateEvidenceUploads < ActiveRecord::Migration[8.0]
  def change
    create_table :evidence_uploads do |t|
      t.integer :evidenceupload_id
      t.integer :questionresponse_id
      t.integer :competencyresponse_id
      t.string :file_type

      t.timestamps
    end
  end
end
