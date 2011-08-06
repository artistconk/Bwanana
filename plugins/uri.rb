require "mechanize"
require "nokogiri"
require "uri"
require "open-uri"

module Plugins
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
end
