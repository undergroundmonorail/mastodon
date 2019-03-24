# frozen_string_literal: true

module Admin
  class SettingsController < BaseController
    ADMIN_SETTINGS = %w(
      site_contact_username
      site_contact_email
      site_title
      site_short_description
      site_description
      site_extended_description
      site_terms
      registrations_mode
      closed_registrations_message
      open_deletion
      timeline_preview
      show_staff_badge
      bootstrap_timeline_accounts
      flavour
      skin
      flavour_and_skin
      thumbnail
      hero
      mascot
      min_invite_role
      activity_api_enabled
      peers_api_enabled
      show_known_fediverse_at_about_page
      preview_sensitive_media
      custom_css
      profile_directory
      hide_followers_count
    ).freeze

    BOOLEAN_SETTINGS = %w(
      open_deletion
      timeline_preview
      show_staff_badge
      activity_api_enabled
      peers_api_enabled
      show_known_fediverse_at_about_page
      preview_sensitive_media
      profile_directory
      hide_followers_count
    ).freeze

    UPLOAD_SETTINGS = %w(
      thumbnail
      hero
      mascot
    ).freeze

    def edit
      authorize :settings, :show?
      @admin_settings = Form::AdminSettings.new
    end

    def update
      authorize :settings, :update?

      settings = settings_params
      flavours_and_skin = settings.delete('flavour_and_skin')
      if flavours_and_skin
        settings['flavour'], settings['skin'] = flavours_and_skin.split('/', 2)
      end

      settings.each do |key, value|
        if UPLOAD_SETTINGS.include?(key)
          upload = SiteUpload.where(var: key).first_or_initialize(var: key)
          upload.update(file: value)
        else
          setting = Setting.where(var: key).first_or_initialize(var: key)
          setting.update(value: value_for_update(key, value))
        end
      end

      flash[:notice] = I18n.t('generic.changes_saved_msg')
      redirect_to edit_admin_settings_path
    end

    private

    def settings_params
      params.require(:form_admin_settings).permit(ADMIN_SETTINGS)
    end

    def value_for_update(key, value)
      if BOOLEAN_SETTINGS.include?(key)
        value == '1'
      else
        value
      end
    end
  end
end
