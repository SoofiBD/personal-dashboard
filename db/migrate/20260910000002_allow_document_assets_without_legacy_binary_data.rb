class AllowDocumentAssetsWithoutLegacyBinaryData < ActiveRecord::Migration[7.2]
  def change
    change_column_null :document_assets, :data, true
  end
end
