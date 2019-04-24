# frozen_string_literal: true

class InitialStateSerializer < ActiveModel::Serializer
  attributes :meta, :compose, :accounts,
             :media_attachments, :settings,
             :max_toot_chars, :soft_max_chars, :poll_limits

  has_one :push_subscription, serializer: REST::WebPushSubscriptionSerializer

  def max_toot_chars
    StatusLengthValidator::MAX_CHARS
  end

  def soft_max_chars
    StatusLengthValidator::SOFT_MAX_CHARS
  end

  def poll_limits
    {
      max_options: PollValidator::MAX_OPTIONS,
      max_option_chars: PollValidator::MAX_OPTION_CHARS,
      min_expiration: PollValidator::MIN_EXPIRATION,
      max_expiration: PollValidator::MAX_EXPIRATION,
    }
  end

  def meta
    store = {
      streaming_api_base_url: Rails.configuration.x.streaming_api_base_url,
      access_token: object.token,
      locale: I18n.locale,
      domain: Rails.configuration.x.local_domain,
      admin: object.admin&.id&.to_s,
      search_enabled: Chewy.enabled?,
      repository: Mastodon::Version.repository,
      source_url: Mastodon::Version.source_url,
      version: Mastodon::Version.to_s,
      invites_enabled: Setting.min_invite_role == 'user',
      mascot: instance_presenter.mascot&.file&.url,
      profile_directory: Setting.profile_directory,
    }

    if object.current_account
      store[:me]              = object.current_account.id.to_s
      store[:unfollow_modal]  = object.current_account.user.setting_unfollow_modal
      store[:boost_modal]     = object.current_account.user.setting_boost_modal
      store[:favourite_modal] = object.current_account.user.setting_favourite_modal
      store[:delete_modal]    = object.current_account.user.setting_delete_modal
      store[:auto_play_gif]   = object.current_account.user.setting_auto_play_gif
      store[:display_media]   = object.current_account.user.setting_display_media
      store[:expand_spoilers] = object.current_account.user.setting_expand_spoilers
      store[:reduce_motion]   = object.current_account.user.setting_reduce_motion
      store[:is_staff]        = object.current_account.user.staff?
    end

    store
  end

  def compose
    store = {}

    if object.current_account
      store[:me]                = object.current_account.id.to_s
      store[:default_privacy]   = object.current_account.user.setting_default_privacy
      store[:default_sensitive] = object.current_account.user.setting_default_sensitive
    end

    store[:text] = object.text if object.text

    store
  end

  def accounts
    store = {}
    store[object.current_account.id.to_s] = ActiveModelSerializers::SerializableResource.new(object.current_account, serializer: REST::AccountSerializer) if object.current_account
    store[object.admin.id.to_s]           = ActiveModelSerializers::SerializableResource.new(object.admin, serializer: REST::AccountSerializer) if object.admin
    store
  end

  def media_attachments
    { accept_content_types: MediaAttachment::IMAGE_FILE_EXTENSIONS + MediaAttachment::VIDEO_FILE_EXTENSIONS + MediaAttachment::AUDIO_FILE_EXTENSIONS + MediaAttachment::IMAGE_MIME_TYPES + MediaAttachment::VIDEO_MIME_TYPES + MediaAttachment::AUDIO_MIME_TYPES }
  end

  private

  def instance_presenter
    @instance_presenter ||= InstancePresenter.new
  end
end
