module PersonalFinance
  class DocumentAssetsController < ApplicationController
    def show
      conversion = owned(DocumentConversion).find(params[:document_conversion_id])
      asset = conversion.assets.find(params[:id])
      send_data asset.data, type: asset.content_type, disposition: "inline", filename: asset.filename
    end
  end
end
