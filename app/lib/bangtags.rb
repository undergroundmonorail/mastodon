# frozen_string_literal: true

class Bangtags
  attr_reader :status, :account

  def initialize(status)
    @status        = status
    @account       = status.account
    @parent_status = Status.find(status.in_reply_to_id) if status.in_reply_to_id

    @prefix_ns = {
      'permalink' => ['link'],
    }

    @aliases = {
      ['media', 'end'] => ['var', 'end'],
      ['media', 'stop'] => ['var', 'end'],
      ['media', 'endall'] => ['var', 'endall'],
      ['media', 'stopall'] => ['var', 'endall'],
    }

    # sections of the final status text
    @chunks = []
    # list of transformation commands
    @tf_cmds = []
    # list of post-processing commands
    @post_cmds = []
    # hash of bangtag variables
    @vars = []
    # keep track of what variables we're appending the value of between chunks
    @var_stack = []
    # keep track of what type of nested components are active so we can !end them in order
    @component_stack = []
  end

  def process
    return unless status.text&.present? && status.text.include?('#!')

    status.text.gsub!('#!!', "#\u200c!")

    status.text.split(/(#!(?:.*:!#|{.*?}|[^\s#]+))/).each do |chunk|
      if @var_stack.last == '_draft' || (@chunks.present? && @chunks.first.include?('#!draft'))
        @chunks << chunk
      elsif chunk.starts_with?("#!")
        chunk.sub!(/(\\:)?+:+?!#\Z/, '\1')
        chunk.sub!(/{(.*)}\Z/, '\1')

        if @var_stack.last != '_comment'
          cmd = chunk[2..-1].strip
          next if cmd.blank?
          cmd = cmd.split(':::')
          cmd = cmd[0].split('::') + cmd[1..-1]
          cmd = cmd[0].split(':') + cmd[1..-1]

          cmd.map! {|c| c.gsub(/\\:/, ':').gsub(/\\\\:/, '\:')}

          prefix = @prefix_ns[cmd[0]]
          cmd = prefix + cmd unless prefix.nil?

          @aliases.each_key do |old_cmd|
            cmd = aliases[old_cmd] + cmd.drop(old_cmd.length) if cmd.take(old_cmd.length) == old_cmd
          end
        elsif chunk.in?(['#!comment:end', '#!comment:stop', '#!comment:endall', '#!comment:stopall'])
          @var_stack.pop
          @component_stack.pop
          next
        else
          next
        end

        next if cmd[0].nil?
        case cmd[0].downcase
        when 'var'
          chunk = nil
          next if cmd[1].nil?
          case cmd[1].downcase
          when 'end', 'stop'
            @var_stack.pop
            @component_stack.pop
          when 'endall', 'stopall'
            @var_stack = []
            @component_stack.reject! {|c| c == :var}
          else
            var = cmd[1]
            next if var.nil? || var.starts_with?('_')
            new_value = cmd[2..-1]
            if new_value.blank?
              chunk = @vars[var]
            elsif new_value.length == 1 && new_value[0] == '-'
              @var_stack.push(var)
              @component_stack.push(:var)
            else
              @vars[var] = new_value.join(':')
            end
          end
        when 'tf'
          chunk = nil
          next if cmd[1].nil?
          case cmd[1].downcase
          when 'end', 'stop'
            @tf_cmds.pop
            @component_stack.pop
          when 'endall', 'stopall'
            @tf_cmds = []
            @component_stack.reject! {|c| c == :tf}
          else
            @tf_cmds.push(cmd[1..-1])
            @component_stack.push(:tf)
          end
        when 'end', 'stop'
          chunk = nil
          case @component_stack.pop
          when :tf
            @tf_cmds.pop
          when :var, :hide
            @var_stack.pop
          end
        when 'endall', 'stopall'
          chunk = nil
          @tf_cmds = []
          @var_stack = []
          @component_stack = []
        when 'emojify'
          chunk = nil
          next if cmd[1].nil?
          src_img = nil
          shortcode = cmd[2]
          case cmd[1].downcase
          when 'avatar'
            src_img = status.account.avatar
          when 'parent'
            next unless cmd[3].present? && reply?
            shortcode = cmd[3]
            next if cmd[2].nil? || @parent_status.nil?
            case cmd[2].downcase
            when 'avatar'
              src_img = @parent_status.account.avatar
            end
          end

          next if src_img.nil? || shortcode.nil? || !shortcode.match?(/\A\w+\Z/)

          chunk = ":#{shortcode}:"
          emoji = CustomEmoji.find_or_initialize_by(shortcode: shortcode, domain: nil)
          if emoji.id.nil?
            emoji.image = src_img
            emoji.save
          end
        when 'emoji'
          next if cmd[1].nil?
          shortcode = cmd[1]
          domain = (cmd[2].blank? ? nil : cmd[2].downcase)
          chunk = ":#{shortcode}:"
          ours = CustomEmoji.find_or_initialize_by(shortcode: shortcode, domain: nil)
          if ours.id.nil?
            if domain.nil?
              theirs = CustomEmoji.find_by(shortcode: shortcode)
            else
              theirs = CustomEmoji.find_by(shortcode: shortcode, domain: domain)
            end
            unless theirs.nil?
              ours.image = theirs.image
              ours.save
            end
          end
        when 'char'
          chunk = nil
          charmap = {
            'zws' => "\u200b",
            'zwnj' => "\u200c",
            'zwj' => "\u200d",
            '\n' => "\n",
            '\r' => "\r",
            '\t' => "\t",
            '\T' => '    '
          }
          cmd[1..-1].each do |c|
            next if c.nil?
            if c.in?(charmap)
              @chunks << charmap[cmd[1]]
            elsif (/^\h{1,5}$/ =~ c) && c.to_i(16) > 0
              begin
                @chunks << [c.to_i(16)].pack('U*')
              rescue
                @chunks << '?'
              end
            end
          end
        when 'link'
          chunk = nil
          next if cmd[1].nil?
          case cmd[1].downcase
          when 'permalink', 'self'
            chunk = TagManager.instance.url_for(status)
          end
        when 'ping'
          mentions = []
          next if cmd[1].nil?
          case cmd[1].downcase
          when 'admins'
            mentions = User.admins.map { |u| "@#{u.account.username}" }
            mentions.sort!
          when 'mods'
            mentions = User.moderators.map { |u| "@#{u.account.username}" }
            mentions.sort!
          when 'staff'
            mentions = User.admins.map { |u| "@#{u.account.username}" }
            mentions += User.moderators.map { |u| "@#{u.account.username}" }
            mentions.uniq!
            mentions.sort!
          end
          chunk = mentions.join(' ')
        when 'tag'
          chunk = nil
          tags = cmd[1..-1].map {|t| t.gsub(':', '.')}
          add_tags(status, *tags)
        when 'thread'
          chunk = nil
          next if cmd[1].nil?
          case cmd[1].downcase
          when 'reall'
            if status.conversation_id.present?
              participants = Status.where(conversation_id: status.conversation_id)
                .pluck(:account_id).uniq.without(@account.id)
              participants = Account.where(id: participants)
                .pluck(:username, :domain)
                .map { |a| "@#{a.compact.join('@')}" }
              participants = (cmd[2..-1].map(&:strip) | participants) unless cmd[2].nil?
              chunk = participants.join(' ')
            end
          when 'emoji'
            next if status.conversation_id.nil?
            roars = Status.where(conversation_id: status.conversation_id, account_id: @account.id)
            roars.each do |roar|
              roar.emojis.each do |theirs|
                ours = CustomEmoji.find_or_initialize_by(shortcode: theirs.shortcode, domain: nil)
                if ours.id.nil?
                  ours.image = theirs.image
                  ours.save
                end
              end
            end
          end
        when 'parent'
          chunk = nil
          next if cmd[1].nil? || @parent_status.nil?
          case cmd[1].downcase
          when 'permalink'
            chunk = TagManager.instance.url_for(@parent_status)
          when 'tag'
            chunk = nil
            next unless @parent_status.account.id == @account.id
            tags = cmd[2..-1].map {|t| t.gsub(':', '.')}
            add_tags(@parent_status, *tags)
          when 'emoji'
            @parent_status.emojis.each do |theirs|
              ours = CustomEmoji.find_or_initialize_by(shortcode: theirs.shortcode, domain: nil)
              if ours.id.nil?
                ours.image = theirs.image
                ours.save
              end
            end
          end
        when 'media'
          chunk = nil

          media_idx = cmd[1]
          media_cmd = cmd[2]
          media_args = cmd[3..-1]

          next unless media_cmd.present? && media_idx.present? && media_idx.scan(/\D/).empty?
          media_idx = media_idx.to_i
          next if status.media_attachments[media_idx-1].nil?

          case media_cmd.downcase
          when 'desc'
            if media_args.present?
              @vars["media_#{media_idx}_desc"] = media_args.join(':')
            else
              @var_stack.push("media_#{media_idx}_desc")
              @component_stack.push(:var)
            end
          end

          @post_cmds.push(['media', media_idx, media_cmd])
        when 'bangtag'
          chunk = chunk.sub('bangtag:', '').gsub(':', ":\u200c")
        when 'join'
          chunk = nil
          next if cmd[1].nil?
          charmap = {
            'zws' => "\u200b",
            'zwnj' => "\u200c",
            'zwj' => "\u200d",
            '\n' => "\n",
            '\r' => "\r",
            '\t' => "\t",
            '\T' => '    '
          }
          sep = charmap[cmd[1]]
          chunk = cmd[2..-1].join(sep.nil? ? cmd[1] : sep)
        when 'hide'
          chunk = nil
          next if cmd[1].nil?
          case cmd[1].downcase
          when 'end', 'stop', 'endall', 'stopall'
            @var_stack.reject! {|v| v == '_'}
            @compontent_stack.reject! {|c| c == :hide}
          else
            if cmd[1].nil? && !'_'.in?(@var_stack)
              @var_stack.push('_')
              @component_stack.push(:hide)
            end
          end
        when 'comment'
          chunk = nil
          if cmd[1].nil?
            @var_stack.push('_comment')
            @component_stack.push(:var)
          end
        when 'draft'
          chunk = nil
          @chunks.insert(0, "[center]`#!draft!#`[/center]\n") unless @chunks.present? && @chunks.first.include?('#!draft')
          status.visibility = :direct
          @var_stack.push('_draft')
          @component_stack.push(:var)
          add_tags(status, 'self.draft')
        when 'format', 'type'
          chunk = nil
          next if cmd[1].nil?
          content_types = {
            't'           => 'text/plain',
            'txt'         => 'text/plain',
            'text'        => 'text/plain',
            'plain'       => 'text/plain',
            'plaintext'   => 'text/plain',

            'm'           => 'text/markdown',
            'md'          => 'text/markdown',
            'markdown'    => 'text/markdown',

            'h'           => 'text/html',
            'htm'         => 'text/html',
            'html'        => 'text/html',
          }
          v = cmd[1].downcase
          status.content_type = content_types[c] unless content_types[c].nil?
        when 'visibility'
          chunk = nil
          next if cmd[1].nil?
          visibilities = {
            'direct'      => :direct,
            'dm'          => :direct,
            'whisper'     => :direct,

            'private'     => :private,
            'packmate'    => :private,
            'group'       => :private,

            'unlisted'    => :unlisted,
            'local'       => :unlisted,
            'glaceon'     => :unlisted,

            'public'      => :public,
            'world'       => :public,
          }
          v = cmd[1].downcase
          status.visibility = visibilities[v] unless visibilities[v].nil?
        when 'keysmash'
          keyboard = [
            'asdf', 'jkl;',
            'gh', "'",
            'we', 'io',
            'r', 'u',
            'cv', 'nm',
            't', 'x', ',',
            'q', 'z',
            'y', 'b',
            'p', '[',
            '.', '/',
            ']', "\\",
          ]

          chunk = rand(6..33).times.collect do
            keyboard[(keyboard.size * (rand ** 3)).floor].split('').sample
          end
        when 'shrug'
          chunk = '¯\\\_(ツ)\_/¯'
        end
      end

      if chunk.present? && @tf_cmds.present?
        @tf_cmds.each do |tf_cmd|
          next if chunk.nil? || tf_cmd[0].nil?
          case tf_cmd[0].downcase
          when 'replace', 'sub', 's'
            tf_cmd[1..-1].in_groups_of(2) do |args|
              chunk.sub!(*args) if args.all?
            end
          when 'replaceall', 'gsub', 'gs'
            tf_cmd[1..-1].in_groups_of(2) do |args|
              chunk.gsub!(*args) if args.all?
            end
          end
        end
      end

      unless chunk.blank? || @var_stack.empty?
        var = @var_stack.last
        next if var == '_'
        if @vars[var].nil?
          @vars[var] = chunk.lstrip
        else
          @vars[var] += chunk.rstrip
        end
        chunk = nil
      end

      @chunks << chunk unless chunk.nil?
    end

    postprocess_before_save

    account.save

    status.text = @chunks.join
    status.save

    postprocess_after_save
  end

  private

  def postprocess_before_save
    @post_cmds.each do |post_cmd|
      case post_cmd[0]
      when 'media'
        media_idx = post_cmd[1]
        media_cmd = post_cmd[2]
        media_args = post_cmd[3..-1]

        case media_cmd
        when 'desc'
          status.media_attachments[media_idx-1].description = @vars["media_#{media_idx}_desc"]
          status.media_attachments[media_idx-1].save
        end
      end
    end
  end

  def postprocess_after_save
    @post_cmds.each do |post_cmd|
      case post_cmd[0]
      when 'mention'
        mention = @account.mentions.where(status: status).first_or_create(status: status)
      end
    end
  end

  def add_tags(to_status, *tags)
    records = []
    valid_name = /^[[:word:]:_\-]*[[:alpha:]:_·\-][[:word:]:_\-]*$/
    tags = tags.select {|t| t.present? && valid_name.match?(t)}.uniq
    ProcessHashtagsService.new.call(to_status, tags)
  end
end
