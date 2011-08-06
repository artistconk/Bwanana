class Twentyone # {{{
  include DataMapper::Resource

  property(:id,         Serial)
  property(:nick,       String)
  property(:value,      Integer)
end # }}}

module Plugins
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
end
