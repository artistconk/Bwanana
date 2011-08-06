module Plugins
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
end
