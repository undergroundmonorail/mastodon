# frozen_string_literal: true

class MuteService < BaseService
  def call(account, target_account, notifications: nil, note: nil)
    return if account.id == target_account.id

    ActiveRecord::Base.transaction do
      mute = account.mute!(target_account, notifications: notifications)
      mute.create_note!(note: note) if !note.blank?
      BlockWorker.perform_async(account.id, target_account.id)
      mute
    end
  end
end
