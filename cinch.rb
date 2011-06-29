#!/usr/bin/ruby
# Channel bot for #pixelfuckers
#
# based on Geass:
#   @copyright (c) 2010, Christoph Kappel <unexist@dorfelite.net>
#   @version $Id: bot/cinch.rb,v 208 2011/01/18 20:56:21 unexist $

# Requires {{{
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
# }}}

# Config {{{
# Server
SERVER      = "irc.freenode.org"
PORT        = 6667
CHANNEL     = "#pixelfuckers"

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

# Database {{{
DataMapper.setup(:default, "sqlite3:///" + DBFILE)

# Models
class Daddy # {{{
  include DataMapper::Resource

  property(:id,         Serial)
  property(:nick,       String)
end # }}}

class Phrase # {{{
  include DataMapper::Resource

  property(:id,         Serial)
  property(:name,       String, :unique => true)
  property(:channel,    String)
  property(:version,    Integer, :default => 0)
  property(:created_at, EpochTime)

  has n, :versions, :model => "Version", :child_key => [ :phrase_id ]

  def latest_version
    return Version.first(:phrase_id => self.id, :version => self.version)
  end

  def has_version?(version)
    return 0 <= version && version <= self.version ? true : false
  end

  def specific_version(version)
    v = nil

    if(self.has_version?(version))
      v = Version.first(:phrase_id => self.id, :version => version)
    end

    return v
  end
end # }}}

class Version # {{{
  include DataMapper::Resource

  property(:id,         Serial)
  property(:phrase_id,  Integer)
  property(:nick,       String)
  property(:value,      Text)
  property(:version,    Integer, :default => 0)
  property(:created_at, EpochTime)

  belongs_to :phrase, :model => "Phrase", :child_key => [ :phrase_id ]
end # }}}

class Score # {{{
  include DataMapper::Resource

  property(:id,         Serial)
  property(:name,       String, :unique => true)
  property(:score,      Integer, :default => 0)
  property(:created_at, EpochTime)
end # }}}

class Poke # {{{
  include DataMapper::Resource

  property(:id,         Serial)
  property(:action,     String, :unique => true)
  property(:nick,       String)
  property(:created_at, EpochTime)
end # }}}

class Weather # {{{
  include DataMapper::Resource

  property(:id,         Serial)
  property(:nick,       String, :unique => true)
  property(:postal,     String)
end # }}}

class Twentyone # {{{
  include DataMapper::Resource

  property(:id,         Serial)
  property(:nick,       String)
  property(:value,      Integer)
end # }}}

class Todo # {{{
  include DataMapper::Resource

  property(:id,         Serial)
  property(:item,       String)
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
  class Scores # {{{
    include Cinch::Plugin
    react_on :channel

    match /(\+\+|--)(.+)/, method: :change
    def change(m, op, key)
      begin
        lookup = key.downcase.strip
        score  = Score.first(:name.like => lookup)

        # New score
        if(score.nil?)
          score = Score.new(
            :name       => lookup,
            :score      => 0,
            :created_at => Time.now
          )
        end

        # In-/decrease score
        if(m.user.nick.downcase.strip == lookup)
          score.score = score.score - 1
        else
          score.score = case op
            when "++" then score.score + 1
            when "--" then score.score - 1
          end
        end

        if(score.score == 0)
          score.destroy!

          m.reply "Zeroed out", true
        else
          score.save

          m.reply "Score of %s is now %d" % [ key, score.score ], true
        end
      rescue => error
        m.reply "Oops something went wrong"
        raise
      end
    end

    match /score (.+)/, method: :score
    def score(m, key)
      begin
        lookup = key.downcase.strip
        score  = Score.first(:name.like => lookup)

        unless(score.nil?)
          m.reply "Score of %s is %d" % [ lookup, score.score ], true
        end
      rescue => error
        m.reply "Oops something went wrong", true
        raise
      end
    end

    match /(best|worst)$/, method: :top_score
    def top_score(m, op)
      begin
        # Get scores
        case op
        when "best"
          scores = Score.all(:order => [ :score.desc ], :limit => 10)
        when "worst"
          scores = Score.all(:score.lt => 0, :order => [ :score.asc ], :limit => 10)
        end

        unless(scores.nil?)
          matches = []

          scores.each do |s|
            matches << "%s[%d]" % [ s.name, s.score ]
          end

          unless(matches.empty?)
            m.reply matches.join(", "), true
          end
        end
      rescue => error
        m.reply "Oops something went wrong", true
        raise
      end
    end
  end # }}}

  class Phrases # {{{
    include Cinch::Plugin
    react_on :channel

    match /^!rem (.+) ([+-]?)= (.+)/, method: :store_phrase, use_prefix: false # {{{
    def store_phrase(m, key, op, value)
      begin
        lookup = key.downcase.strip
        phrase = Phrase.first(:name => lookup)

        if(phrase.nil?) #< New phrase
          phrase = Phrase.new(
            :name       => lookup,
            :channel    => m.channel.name,
            :version    => 0,
            :created_at => Time.now
          )
          phrase.save

          version = Version.new(
            :phrase_id  => phrase.id,
            :nick       => m.user.nick,
            :value      => value,
            :version    => 0,
            :created_at => Time.now
          )
          version.save
        else #< New version
          case op
          when "+"
            v = phrase.latest_version
            v.value = "%s %s" % [ v.value, value ]
            v.save
          when "-"
            v = phrase.latest_version
            v.value = v.value.sub(/#{value.strip}/, "").strip
            v.save
          else
            version = Version.new(
              :phrase_id  => phrase.id,
              :nick       => m.user.nick,
              :value      => value,
              :version    => phrase.version + 1,
              :created_at => Time.now
            )
            version.save

            # Increase version
            phrase.version = phrase.version + 1
            phrase.save
          end
        end

        m.reply "a'ight", true
      rescue
        m.reply "Oops something went wrong", true
        raise
      end
    end # }}}

    match /^([0-9]*)?\!give ([^ ]+) ([^ ]+)((?:\s(?:[^ ]*))*)/, method: :give_phrase, use_prefix: false # {{{
    def give_phrase(m, version, target, key, args)
      begin
        phrase, *args = phrase_args(key, args)

        unless(phrase.nil?)
          # Get phrase
          if(!version.empty? and phrase.has_version?(version.to_i))
            v = phrase.specific_version(version.to_i)
          else
            v = phrase.latest_version
          end

          m.reply "%s: %s" % [ target, replace_args(v.value, args) ]
        else
          m.reply "Did you mean: %s" % [ find_alike(key, 5) ], true
        end
      rescue
        m.reply "Oops something went wrong", true
        raise
      end
    end # }}}

    match /^!find (.+)/, method: :find_phrase, use_prefix: false # {{{
    def find_phrase(m, key)
      begin
        likes = find_alike(key)
        m.reply "Matches for %s: %s" % [ key, likes ], true unless(likes.empty?)
      rescue
        m.reply "Oops something went wrong", true
        raise
      end
    end # }}}

    match /^(\d+)?!forget (.+)/, method: :forget_phrase, use_prefix: false # {{{
    def forget_phrase(m, version, key)
      begin
        lookup = key.downcase.strip
        phrase = Phrase.first(:name => lookup)

        unless(phrase.nil?)
          # Get phrase
          if(!version.nil? and phrase.has_version?(version.to_i))
            v = phrase.specific_version(version.to_i)
          else
            v = phrase.latest_version
          end

          # Check owner
          if v.nick == m.user.nick or isdaddy(m.user)
            v.destroy!

            # Delete version or whole phrase
            if(0 == phrase.version)
              phrase.destroy!
            else
              phrase.version = phrase.version - 1
              phrase.save
            end

            m.reply "a'ight", true
          else
            m.reply "Not yours", true
          end
        else
          likes = find_alike(key, 5)
          m.reply "Did you mean: %s" % [ likes  ], true unless(likes.empty?)
        end
      rescue
        m.reply "Oops something went wrong", true
        raise
      end
    end # }}}

    match /^([0-9]*)?(\!|\?)([^ ]+)((?:\s(?:[^ ]*))*)/, method: :get_phrase, use_prefix: false # {{{
    def get_phrase(m, version, op, key, args)
      begin
        # FIXME: Exlude keywords until groups are implemented
        return if([ "rem", "give", "find", "forget" ].include?(key))

        phrase, *args = phrase_args(key, args)

        unless(phrase.nil?)
          # Get phrase version
          if(!version.empty? and phrase.has_version?(version.to_i))
            v = phrase.specific_version(version.to_i)
          else
            v = phrase.latest_version
          end

          # Output based on op
          case op
            when "!"
              m.reply replace_args(v.value, args)
            when "?"
              m.reply "'%s' is '%s' (%s, %s, r%d)" % [
                key, v.value,
                v.created_at.strftime("on %Y-%m-%d at %H:%M:%S"),
                v.nick, v.version
              ], true
          end
        else
          likes = find_alike(key, 5)
          m.reply "Did you mean: %s" % [ likes ], true unless(likes.empty?)
        end
      rescue
        m.reply "Oops something went wrong", true
        raise
      end
    end # }}}

    private

    def replace_args(value, args = []) # {{{
      value.gsub!(/(?:\${?([1-9]+)(-?)(?::([a-z]*))?}?)/) do |s|
        unless(args.empty?)
          match, idx, dash, meth = $~.to_a

          # Get index
          idx = idx.nil? ? 0 : idx.to_i - 1

          # Join args or just select one
          if("-" == dash)
            arg = args.slice(idx, args.size).join(" ")
          else
            arg = args[idx]
          end

          # Use string modifier
          case meth
            when "upcase"     then arg.upcase
            when "downcase"   then arg.downcase
            when "reverse"    then arg.reverse
            when "capitalize" then arg.capitalize
            else                   arg
          end
        else
          nil
        end
      end

      value
    end # }}}

    def phrase_rand(phrase) # {{{
      if(phrase.latest_version.value.match(/\$rand\(((?:[\s,]*(?:[^ ]+))+)\)/))
        list  = $~[1].gsub(/[\*\+ ]/, "*" => "%", "+" => "_", " " => "").split(",")

        phrases = Phrase.all(:name.like => list.shift)

        # Use AND to find all useable phrases
        list.each do |l|
          phrases += Phrase.all(:name.like => l)
        end

        # Exclude phrase with rand
        phrases -= phrase

        # Get random phrase
        r = rand(phrases.size)

        phrases[r]
      else
        phrase
      end
    end # }}}

    def phrase_args(key, args = []) # {{{
      lookup = key.downcase.strip
      arg    = ""

      # Split args
      args = args.split(" ") if(args.is_a?(String))

      # Get phrase and check if args are part of it
      begin
        lookup << " #{arg}" unless(arg.nil? or arg.empty?)

        phrase = Phrase.first(:name => lookup)

        arg = args.shift if(phrase.nil?)
      end while(phrase.nil? and arg.is_a?(String) and !arg.empty?)

      # Random
      phrase = phrase_rand(phrase) unless(phrase.nil?)

      [ phrase, *args ]
    end # }}}

    def find_alike(key, limit = 10) # {{{
      result  = ""
      lookup  = key.downcase.strip
      phrases = Phrase.all(:name.like => "%#{lookup}%", :limit => limit)

      unless(phrases.nil?)
        matches = []

        phrases.each do |p|
          matches << "%s[%d]" % [ p.name, p.version ]
        end

        result = matches.join(", ") unless(matches.empty?)
      end

      result
    end # }}}

  end # }}}

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

    match /poke (.+)/, method: :poke
    def poke(m, nick)
      r = rand(Poke.all.size)
      poke = Poke.all[r].action.sub("%s", nick)
      m.reply "%s %s" % [ m.user.nick, poke ]
    rescue
      m.reply "Oops something went wrong", true
    end
  end
  # }}}

  class Cookies # {{{
    include Cinch::Plugin
    react_on :channel

    match /cookie (.+)/, method: :poke
    def poke(m, nick)
      m.reply "%s gives a cookie to %s" % [ m.user.nick, nick ]
    end
  end # }}}

  class IsItDown # {{{
    include Cinch::Plugin
    react_on :channel

    match /isitdown (.+)/
    def execute(m, uri)
      # Create mechanize agent
      if(@agent.nil?)
        @agent = Mechanize.new
        @agent.user_agent_alias = "Linux Mozilla"
      end

      page  = @agent.get("http://downforeveryoneorjustme.com/%s" % [ uri ])
      title = page.title.gsub(/[\x00-\x1f]*/, "").gsub(/[ ]{2,}/, " ").strip

      m.reply title, true
    end
  end # }}}

  class Uri # {{{
    include Cinch::Plugin
    react_on :channel

    listen_to :channel
    def listen(m)
      # Create mechanize agent
      if(@agent.nil?)
        @agent = Mechanize.new
        @agent.user_agent_alias = "Linux Mozilla"
      end

      URI.extract(m.message, ["http", "https"]) do |link|
        # Fetch data
        uri  = URI.parse(link)
        page = @agent.get(link)

        # Replace strange characters
        title = page.title.gsub(/[\x00-\x1f]*/, "").gsub(/[ ]{2,}/, " ").strip

        # Check host
        case uri.host
          when "www.imdb.com"
            # Get user rating
            rating = page.search("//span[@class='rating-rating']").text

            # Get votes
            votes = page.search("//a[@href='ratings']").text.gsub(/[,votes ]/, "")

            m.reply "Title: %s (at %s, %s with %s votes)" % [
              title, uri.host, rating, votes
            ]
          when "www.youtube.com"
            # Get page hits
            hits = page.search("//span[@class='watch-view-count']/strong")
            hits = hits.text.gsub(/[.,]/, "")

            # Get likes/dislikes
            likes    = page.search("//span[@class='likes']")
            dislikes = page.search("//span[@class='dislikes']")

            # Check arrays
            likes    = likes.first    if(likes.is_a?(Nokogiri::XML::NodeSet))
            dislikes = dislikes.first if(dislikes.is_a?(Nokogiri::XML::NodeSet))

            likes    = likes.text.gsub(/[.,]/, "")
            dislikes = dislikes.text.gsub(/[.,]/, "")

            m.reply "Title: %s (at %s, %s hits, %s/-%s (dis)likes)" % [
              title, uri.host, hits, likes, dislikes
            ]
          when "gist.github.com"
            # Get owner
            owner = page.search("//div[@class='name']/a").inner_html

            # Get time
            age = Time.parse(page.search("//span[@class='date']/abbr").text)
            age = age.strftime("%Y-%m-%d %H:%M")

            m.reply "Title: %s (at %s, %s on %s)" % [
              title, uri.host, owner, age
            ]
          when "pastie.org"
            # Get time
            age = Time.parse(page.search("//span[@class='typo_date']").text)
            age = age.strftime("%Y-%m-%d %H:%M")

            m.reply "Title: %s (at %s, on %s)" % [
              title, uri.host, age
            ]
          else
            m.reply "Title: %s (at %s)" % [ title, uri.host ]
          end
      end
    end
  end # }}}

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

  class Damnyou # {{{
    include Cinch::Plugin
    react_on :channel

    match /damn (.+)/, method: :damn_something
    def damn_something(m, phrase)
      m.reply "damn you, you little #{phrase.upcase}! i'm going to strangle you"
    end
  end # }}}

  class Submissions # {{{
    include Cinch::Plugin
    react_on :channel

    timer INTERVAL, method: :updatefeed
    def updatefeed
      feed = Nokogiri::XML(open(FEED))
      sub = feed.css("entry").first
      new = sub.css("title").inner_text.to_s
      if defined? @old
        printnew(sub) unless new == @old
      end
      @old = new
    end

    def printnew(entry)
      Channel(CHANNEL).send "New Submission: %s by %s - %s" % [ 
        entry.css("title").inner_text,
        entry.css("author").inner_text.split.join,
        entry.css("link").to_s.split("\"")[5]
      ]
    end
  end # }}}

  class Google # {{{
    include Cinch::Plugin
    match /google (.+)/

    def search(query)
      url = "http://www.google.com/search?q=#{CGI.escape(query)}"
      res = Nokogiri::HTML(open(url)).at("h3.r")

      title = res.text
      link = res.at('a')[:href]
      desc = res.at("./following::div").children.first.text
      CGI.unescape_html "#{title} - #{desc} (#{link})"
    rescue
      "No results found"
    end

    def execute(m, query)
      m.reply(search(query))
    end
  end # }}}

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

  class Weathers # {{{
    include Cinch::Plugin
    react_on :channel

    match /weather help/, method: :help

    match /weather$/, method: :report
    match /weather report(.+)/, method: :report
    def report(m, param = nil) # {{{
      postal = get_user_postal(m, param)
      return if postal.nil?

      weather = Nokogiri::XML(open(weatherurl(postal)))
      if weather.xpath("//cc")
        m.reply "Location: #{weather.xpath('//loc/dnam').inner_text} - Updated at: #{weather.xpath('//cc/lsup').text}"
        current = "Temp: #{weather.xpath('//cc/tmp').text}F/#{convert_to_c(weather.xpath('//cc/tmp').text)}C - "
        current << "Feels like: #{weather.xpath("//cc/flik").text}F/#{convert_to_c(weather.xpath("//cc/flik").text)}C - "
        current << "Wind: #{weather.xpath("//cc/wind/t").text} #{weather.xpath("//cc/wind/s").text} MPH - "
        current << "Conditions: #{weather.xpath("//cc/t").text} - "
        current << "Humidity: #{weather.xpath("//cc/hmid").text}%"
        m.reply current
      else
        m.reply "City code not found."
      end
    end # }}}

    match /weather forecast(.+)*/, method: :forecast
    def forecast(m, param) # {{{
      postal = get_user_postal(m, param)
      return if postal.nil?

      weather = Nokogiri::XML(open(weatherurl(postal) + "&dayf=5"))
      if weather.xpath('//dayf')
        m.reply "Location: #{weather.xpath('//loc/dnam').inner_text}"
        weather.xpath('//dayf/day').each do |day|
          forecast = "#{day['t']} #{day['dt']} - High: #{day.xpath('hi').text}F/#{convert_to_c(day.xpath('hi').text)}C"
          forecast << "# - Low: #{day.xpath('low').text}F/#{convert_to_c(day.xpath('low').text)}C"

          day.xpath('part').each do |part|
            if part['p'] == "n"
              forecast << " - Night: #{part.xpath('t').text}"
            else
              forecast << " - Day: #{part.xpath('t').text}"
            end
          end
          m.reply forecast
        end
      else
        m.reply "City code not found."
      end
    end # }}}

    match /weather search (.+)/, method: :search
    def search(m, postal) # {{{
      weather = Nokogiri::XML(open("http://xoap.weather.com/search/search?where=#{postal}"))
      if weather.xpath('/search/loc')
        locations = []
        weather.xpath('/search/loc').each do |location|
          locations << "#{location.text} (#{location['id']})"
        end
        m.reply(locations.join(", "))
      else
        m.reply "City code not found."
      end
    end # }}}

    match /weather map(.+)/, method: :map
    def map(m, postal) # {{{
      postal = get_user_postal(m, postal)
      return if postal.nil?
      m.reply "http://www.weather.com/weather/map/interactive/#{postal}"
    end # }}}

    match /weather convert (.+)/, method: :convert
    def convert(m, temp) # {{{
      if temp =~ /^([\-0-9]*)([Ff]|[Cc])$/
        value = $1
        if $2 =~ /F|f/
          to = "C"
          from = "F"
          conversion = convert_to_c(value)
        else
          to = "F"
          from = "C"
          conversion = convert_to_f(value)
        end

        if conversion == "N/A"
          m.reply "Conversion returned null, please try again."
        else
          m.reply("#{temp} converts to #{conversion}#{to}")
        end
      else
        m.reply "Cannot convert that temperature, please try again."
      end
    end # }}}

    match /weather save (.+)/, method: :save
    def save(m, postal) # {{{
      begin
        old = Weather.first(:nick => m.user.nick)
        old.destroy! unless old.nil?

        new = Weather.new(
          :nick     => m.user.nick,
          :postal   => postal
        )
        new.save

        m.reply "a'ight", true
      rescue
        m.reply "Oops something went wrong", true
        raise
      end
    end # }}}

    private

    def weatherurl(postal) # {{{
      return "http://xoap.weather.com/weather/local/#{postal}?par=#{WEATHER_PAR}&key=#{WEATHER_API}&cc=*"
    end # }}}

    def get_user_postal(m, param) # {{{
      if param == '' || param.nil?
        postal = Weather.first(:nick => m.user.nick)
        if postal.nil?
          m.reply "Postal code not provided nor on file."
          return nil
        else
          return postal.postal
        end
      else
        return param.strip
      end
    end # }}}

    def convert_to_c(value) # {{{
      if value =~ /^[\-0-9]*$/
        ( value.to_i - 32 ) * 5 / 9
      else
        "N/A"
      end
    end # }}}

    def convert_to_f(value) # {{{
      if value =~ /^[-0-9]*$/
        ((value.to_i * 9) / 5 ) + 32
      else
        "N/A"
      end
    end # }}}
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

  class Identify # {{{
    include Cinch::Plugin

    listen_to :connect, method: :identify
    def identify(m)
      User("nickserv").send("identify " + SECRET)
    end
  end # }}}

  class Twentyones # {{{
    include Cinch::Plugin
    react_on :channel

    match /twentyone/, method: :starttwentyone
    def starttwentyone(m)
      Twentyone.all(:nick => m.user.nick).destroy!
      4.times do
        roll(m.user.nick)
      end

      gettotal(m.user.nick)
      m.reply "Starting a game of 21 - Your dice: %s- Total %s" % [
        @string,
        @total
      ]
      reply(m, @total)
    end

    match /roll/, method: :rollagain
    def rollagain(m)
      if Twentyone.first(:nick => m.user.nick).nil?
        m.reply "No Game started yet", true
      else
        roll(m.user.nick)
        gettotal(m.user.nick)
        m.reply "Your dice: %s- Total %s" % [
          @string,
          @total
        ], true
        reply(m, @total)
      end
    end

    match /stand/, method: :stay
    def stay(m)
      if Twentyone.first(:nick => m.user.nick).nil?
        m.reply "No Game started yet", true
      else
        dice = Array.new
        count = 0
        until count >= 18
          value = 1 + rand(6)
          dice << value
          count = count + value
        end

        string = ""
        dice.each do |d|
          string = string + d.to_s + " "
        end
        m.reply "Dealer rolls %s- Total %s" % [ string, count ]

        gettotal(m.user.nick)
        if @total > count or count > 21
          m.reply "Your score: %s. You win :)" % [ @total ], true
        elsif @total == count
          m.reply "Your score: %s. Tie!" % [ @total ], true
        elsif @total < count and count <= 21
          m.reply "Your score: %s. You lose :(" % [ @total ], true
        end
        Twentyone.all(:nick => m.user.nick).destroy!
      end
    end

    private

    def roll(nick)
      roll = 1 + rand(6)
      die = Twentyone.new(
        :nick   => nick,
        :value  => roll
      )
      die.save
    end

    def gettotal(nick)
      dice = Twentyone.all(:nick => nick)
      @total = 0
      @string = ""
      dice.each do |d|
        @string = @string + d.value.to_s + " "
        @total = @total + d.value
      end
    end

    def reply(m, total)
      if total > 21
        Twentyone.all(:nick => m.user.nick).destroy!
        m.reply "You're over 21. Busted!", true
      elsif total == 21
        Twentyone.all(:nick => m.user.nick).destroy!
        m.reply "You got 21. Congratulations!", true
      else
        m.reply "!roll to roll again, !stand to stay."
      end
    end

  end # }}}

  class Todos # {{{
    include Cinch::Plugin

    match /remtodo (.+)/, method: :remember
    match /todo rem (.+)/, method: :remember
    def remember(m, item)
      Todo.create(:item => item)
      m.reply "a'ight", true
    rescue
      m.reply "Oops, something went wrong", true
    end

    match /forgettodo (.+)/, method: :forget
    match /todo forget (.+)/, method: :forget
    def forget(m, itemid)
      Todo.get(itemid).destroy
      m.reply "a'ight", true
    rescue
      m.reply "Oops, something went wrong", true
    end

    match /todo list/, method: :list
    match /todo/, method: :list
    def list(m)
      todos = []
      Todo.all.each { |s|
        todos << "%s: %s" % [s.id, s.item]
      }
      m.reply todos.join("\n")
    rescue
      m.reply "Oops, something went wrong", true
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
    Plugins::Damnyou,
    Plugins::Submissions,
    Plugins::Google,
    Plugins::Rename,
    Plugins::Pokes,
    Plugins::Cookies,
    Plugins::Weathers,
    Plugins::Daddies,
    Plugins::Identify,
    Plugins::Twentyones,
    Plugins::Todos
  ]
  end # }}}
end # }}}
bot.start
