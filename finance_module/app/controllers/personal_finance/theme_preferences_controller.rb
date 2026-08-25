module PersonalFinance
  class ThemePreferencesController < ApplicationController
    def update
      preference = params[:theme_preference].to_s
      if %w[dark light system].include?(preference)
        current_panel_user.update!(theme_preference: preference)
        redirect_back fallback_location: finance_root_path, notice: "Tema tercihi güncellendi."
      else
        redirect_back fallback_location: finance_root_path, alert: "Geçersiz tema tercihi."
      end
    end
  end
end
