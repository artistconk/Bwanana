class Todo # {{{
  include DataMapper::Resource

  property(:id,         Serial)
  property(:item,       String)
end # }}}

module Plugins
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
    match /todo$/, method: :list
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
end
