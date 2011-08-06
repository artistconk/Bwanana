module Plugins
  class Rename
    include Cinch::Plugin
    listen_to :quit, method: :listen
    def listen(m)
      @bot.nick = "Bwanana" if m.user.nick == "Bwanana"
    end
  end
end
