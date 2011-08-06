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

module Plugins
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
end
