module Plugins
  class Cookies # {{{
    include Cinch::Plugin
    react_on :channel

    match /cookie (.+)/, method: :poke
    def poke(m, nick)
      m.reply "%s gives a cookie to %s" % [ m.user.nick, nick ]
    end
  end # }}}
end
