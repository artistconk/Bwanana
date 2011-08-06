#!/usr/bin/ruby
# Channel bot for #pixelfuckers
#
# based on Geass:
#   @copyright (c) 2010, Christoph Kappel <unexist@dorfelite.net>
#   @version $Id: bot/cinch.rb,v 208 2011/01/18 20:56:21 unexist $

# Config {{{
# Server
SERVER      = "localhost"
PORT        = 6667
CHANNEL     = "#Bwanana"

# Bot
NICK        = "Bwanana"
SECRET      = "doyoureallythinkiputthisinhere"
INTERVAL    = 300

# RSS Feed
FEED        = "http://pixelfuckers.org/submissions.atom"

# Weather.com API
WEATHER_PAR = "1079693758"
WEATHER_API = "a6939d9b2b51255c"

# Database
DBFILE      = "/home/crshd/.config/cinch/database.db"
# }}}

# Requires
$:.unshift("#{Dir.pwd}/plugins")

# Gems
require "rubygems"
require "cinch"
require "cgi"
require "dm-core"
require "dm-types"
require "dm-migrations"
require "mechanize"
require "nokogiri"
require "open-uri"
require "uri"
require "time"

# Plugins
require "actions"
require "admin"
require "cookies"
require "google"
require "identify"
require "isitdown"
require "lasturl"
require "phrases"
require "pokes"
require "scores"
require "submissions"
require "todo"
require "twentyone"
require "uri"
require "weather"

# Database {{{
DataMapper.setup(:default, "sqlite3:///" + DBFILE)

# Models
class Daddy # {{{
  include DataMapper::Resource

  property(:id,         Serial)
  property(:nick,       String)
end # }}}



# If database doesn't exist, create. Else update
if(!File.exists?(DBFILE))
  DataMapper.auto_migrate!
elsif(File.exists?(DBFILE))
  DataMapper.auto_upgrade!
end

# }}}

# Plugins {{{
module Plugins



  class Rename # {{{
    include Cinch::Plugin

    listen_to :quit, method: :listen
    def listen(m)
      @bot.nick = "Bwanana" if m.user.nick == "Bwanana"
    end

    match /rename (.+)/, method: :rename
    def rename(m, name)
      if isdaddy(m.user)
        @bot.nick = name
        m.reply "a'ight", true
      else
        m.reply "Can't do that", true
      end
    end

  end # }}}


  class Daddies # {{{
    include Cinch::Plugin
    react_on :channel

    match /whosyourdaddy/, method: :daddy
    def daddy(m)
      begin
        d = Daddy.first
        if d.nil?
          dad = Daddy.new(
            :nick   => m.user.nick
          )
          dad.save

          m.reply "You're my daddy!", true
        elsif isdaddy(m.user)
          m.reply "I wuv you daddy!", true
        else
          m.reply "You're not my daddy", true
        end
      rescue
        m.reply "Oops, something went wrong", true
        raise
      end
    end

    match /alsodaddy (.+)/, method: :alsodaddy
    def alsodaddy(m, nick)
      begin
        if isdaddy(m.user)
          dad = Daddy.new(
            :nick   => nick
          )
          dad.save

          m.reply "a'ight", true
        else
          m.reply "You're not my daddy", true
        end
      rescue
        m.reply "Oops, something went wrong", true
      end
    end

  end # }}}




end # }}}

# Helpers {{{
def isdaddy(user)
  d = Daddy.first(:nick => user.nick)
  not d.nil?
end # }}}

# Create bot {{{
bot = Cinch::Bot.new do
  configure do |c| # {{{
  c.nick            = NICK
  c.server          = SERVER
  c.port            = PORT
  c.channels        = [ CHANNEL ]
  c.plugins.plugins = [
    Plugins::IsItDown,
    Plugins::Scores,
    Plugins::Uri,
    Plugins::Phrases,
    Plugins::Actions,
    Plugins::Submissions,
    Plugins::Google,
    Plugins::Rename,
    Plugins::Pokes,
    Plugins::Cookies,
    Plugins::Weathers,
    Plugins::Daddies,
    Plugins::Identify,
    Plugins::Twentyones,
    Plugins::Todos,
    Plugins::LastUrls
  ]
  end # }}}
end # }}}
bot.start
