class Weather # {{{
  include DataMapper::Resource

  property(:id,         Serial)
  property(:nick,       String, :unique => true)
  property(:postal,     String)
end # }}}

module Plugins
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
end
