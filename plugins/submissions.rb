module Plugins
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
end
