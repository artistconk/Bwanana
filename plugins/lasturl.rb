class LastUrl # {{{
  include DataMapper::Resource

  property(:id,         Serial)
  property(:link,       String)
  property(:user,       String)
end # }}}

module Plugins
  class LastUrls # {{{
    include Cinch::Plugin
    react_on :channel

    listen_to :channel
    def listen(m)
      url = m.message.scan(/(http[^\s]*)/)
      url.each { |u|
        LastUrl.create(
          :user => m.user.nick,
          :link => u.first
        )
      }
    end

    match /lasturl ([1-9]*) (.+)/, method: :list
    def list(m, num, user)
      urls = LastUrl.all(:user => user)

      num = num.to_i
      num = urls.size if num > urls.size

      list = []
      urls[-num..urls.size].each { |s|
        list << "-- #{s.link}"
      }
      m.reply list.join("\n")
    rescue
      m.reply "Oops, something went wrong", true
    end
  end # }}}
end
