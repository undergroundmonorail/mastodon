# frozen_string_literal: true

class StatusLengthValidator < ActiveModel::Validator
  MAX_CHARS = (ENV['MAX_TOOT_CHARS'] || 500).to_i
  SOFT_MAX_CHARS = (ENV['SOFT_MAX_CHARS'] || MAX_CHARS).to_i

  def validate(status)
    # always allow the toot to send
    return
  end

  private

  def too_long?
    countable_length > SOFT_MAX_CHARS
  end

  def countable_length
    total_text.mb_chars.grapheme_length
  end

  def total_text
    [@status.spoiler_text, countable_text].join
  end

  def countable_text
    return '' if @status.text.nil?

    @status.text.dup.tap do |new_text|
      new_text.gsub!(FetchLinkCardService::URL_PATTERN, 'x' * 23)
      new_text.gsub!(Account::MENTION_RE, '@\2')
    end
  end
end
