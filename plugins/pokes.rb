class Poke # {{{
  include DataMapper::Resource

  property(:id,         Serial)
  property(:action,     String, :unique => true)
  property(:nick,       String)
  property(:created_at, EpochTime)
end # }}}

module Plugins
  class Pokes # {{{
    include Cinch::Plugin
    react_on :channel

    match /rempoke (.+)/, method: :addpoke
    match /poke rem (.+)/, method: :addpoke
    def addpoke(m, action)
      poke = Poke.new(
        :action     => action,
        :nick       => m.user.nick,
        :created_at => Time.now
      )
      poke.save

      m.reply "a'ight", true
    rescue
      m.reply "Oops something went wrong", true
    end

    match /forgetpoke (.+)/, method: :removepoke
    match /poke forget (.+)/, method: :removepoke
    def removepoke(m, action)
      p = Poke.first(:action => action)
      if m.user.nick == p.nick or isdaddy(m.user)
        p.destroy!
        m.reply "a'ight", true
      else
        m.reply "Not yours", true
      end
    rescue
      m.reply "Oops something went wrong", true
    end

    match /poke ((?!forget|rem).+)/, method: :poke
    def poke(m, nick)
      r = rand(Poke.all.size)
      poke = Poke.all[r].action.sub("%s", nick)
      m.reply "%s %s" % [ m.user.nick, poke ]
    rescue
      m.reply "Oops something went wrong", true
    end
  end
  # }}}
end
