module Plugins
  class Actions # {{{
    include Cinch::Plugin
    react_on :channel

    match /^\001ACTION (.+)\001$/, method: :action, use_prefix: false
    def action(m, text)
      case text.strip
        when "kicks %s" % [ NICK ]
          m.reply "Ow", true
      end
    end
  end # }}}
end
