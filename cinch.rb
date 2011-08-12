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

# Gems
require "rubygems"
require "cinch"
require "dm-core"
require "dm-types"
require "dm-migrations"
require "time"

# Plugins
$LOAD_PATH << "./plugins"
require "actions"
require "admin"
require "cookies"
require "google"
require "identify"
require "isitdown"
require "lasturl"
require "phrases"
require "pokes"
require "rename"
require "scores"
require "submissions"
require "todo"
require "twentyone"
require "uri"
require "weather"

# Database
DataMapper.setup(:default, "sqlite3:///" + DBFILE)

# If database doesn't exist, create. Else update
if(!File.exists?(DBFILE))
  DataMapper.auto_migrate!
elsif(File.exists?(DBFILE))
  DataMapper.auto_upgrade!
end

# Create bot
bot = Cinch::Bot.new do
  configure do |c| # {{{
  c.nick            = NICK
  c.server          = SERVER
  c.port            = PORT
  c.channels        = [ CHANNEL ]
  c.plugins.plugins = [
    Plugins::IsItDown,
    Plugins::Scores,
    Plugins::Phrases,
    Plugins::Actions,
    Plugins::Submissions,
    Plugins::Google,
    Plugins::Rename,
    Plugins::Pokes,
    Plugins::Cookies,
    Plugins::Weathers,
    Plugins::Admins,
    Plugins::Identify,
    Plugins::Twentyones,
    Plugins::Todos,
    Plugins::LastUrls
  ]
  end
end
bot.start
