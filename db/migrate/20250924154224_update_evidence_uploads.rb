class UpdateEvidenceUploads < ActiveRecord::Migration[8.0]
  def change
    remove_column :evidence_uploads, :file_type, :string
    add_column :evidence_uploads, :link, :string
  end
end
