class Admin
  include DataMapper::Resource

  property(:id,         Serial)
  property(:nick,       String)
end

module Plugins
  class Admins
    include Cinch::Plugin

    react_on :private

    match /rename (.+)/, method: :rename
    def rename(m, name)
      if _isadmin(m.user)
        @bot.nick = name
        m.reply "a'ight", true
      else
        m.reply "Can't do that", true
      end
    end

    match /makeadmin (.+)/, method: :makeadmin
    def makeadmin(m, nick)
      begin
        if _isadmin(m.user)
          admin = Admin.new(
            :nick   => nick
          )
          admin.save

          m.reply "a'ight", true
        else
          m.reply "You're not my daddy", true
        end
      rescue
        m.reply "Oops, something went wrong", true
      end
    end

    match /whosyourdaddy/, method: :daddy
    def daddy(m)
      begin
        d = Admin.first
        if d.nil?
          admin = Admin.new(
            :nick   => m.user.nick
          )
          admin.save

          m.reply "You're my daddy!", true
        elsif _isadmin(m.user)
          m.reply "I wuv you daddy!", true
        else
          m.reply "You're not my daddy", true
        end
      rescue
        m.reply "Oops, something went wrong", true
        raise
      end
    end

  end
end

# Helpers

def _isadmin(user)
  d = Admin.first(:nick => user.nick)
  not d.nil?
end
