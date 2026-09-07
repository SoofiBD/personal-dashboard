module PersonalFinance
  class DocumentAssetsController < ApplicationController
    before_action :set_asset

    def show
      data = (params[:original] == "1") ? @asset.file.download : @asset.binary_data
      response.headers["Cache-Control"] = "no-store"
      send_data data, type: @asset.content_type, disposition: "inline", filename: @asset.filename
    end

    def update
      bounds = %w[left top width height].index_with { |key| Integer(params.require(key).to_s, 10) }
      unless bounds.values.all? { |value| value >= 0 } && bounds["width"] > 0 && bounds["height"] > 0 &&
          bounds["left"] + bounds["width"] <= @asset.width && bounds["top"] + bounds["height"] <= @asset.height
        return render json: {error: "Kırpma alanı görsel sınırları içinde olmalı."}, status: :unprocessable_entity
      end

      data = PdfConversionClient.new.crop_image(asset: @asset, bounds: bounds)
      @asset.cropped_file.attach(io: StringIO.new(data), filename: @asset.filename, content_type: @asset.content_type)
      render json: {saved: true}
    rescue ArgumentError, ActionController::ParameterMissing
      render json: {error: "Geçerli bir kırpma alanı seçin."}, status: :unprocessable_entity
    rescue PdfConversionClient::Error => error
      render json: {error: error.message}, status: :unprocessable_entity
    end

    # Only removes the edit; the extracted original is retained.
    def destroy
      @asset.cropped_file.purge
      render json: {saved: true}
    end

    private

    def set_asset
      conversion = owned(DocumentConversion).find(params[:document_conversion_id])
      @asset = conversion.assets.find(params[:id])
    end
  end
end
