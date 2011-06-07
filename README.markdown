## Daddy

This is used to register a user as admin. This is the first thing you should do when after setting up the bot

**!whosyourdaddy**  
registers yourself as admin. Only works one time.  
_!whosyourdaddy_

**!alsodaddy**  
if used by an admin, this adds another user as admin  
_!alsodaddy crshd_

## Scoring System

This one it easy. The bot allows users to score each other, and saves all the scores to a database.

**!++**  
to increase somebody’s score by 1  
_!++crshd_

**!--**  
to decrease somebody’s score by 1  
_!--crshd_

But beware, if you try to increase your own score, the bot will actually decrease it by 1, to punish you for cheating :D

**!score**  
shows current score  
_!score crshd_

**!best**  
shows the top 10  
_!best_

**!worst**  
shows the last 10  
_!worst_

## IsItDown

This one’s even easier

**!isitdown**  
checks if the website at is really down, of if it’s just you  
_!isitdown google.com_

## Google

**!google**  
does a google search, and returns the top result  
_!google search_

## Damn

**!damn**  
takes , and returns “damn you, you little ! i’m going to strangle you!”  
_!damn Bart_

I created that one out of frustration about my router, which constantly disconnects me…

## Phrases

This is where it gets interesting. Anybody can create new phrases. You know, the things where you type “!” and the bot says something. It’s pretty easy:

### Create

**!rem =**  
sets a phrase  
_!rem foo = bar_  
!foo now return "bar"

**!rem +=**  
adds to an already existing phrase  
_!rem foo += bar_  
!foo now returns "barbar"

**!rem -=**  
removes text from an existing phrase  
_!rem foo -= bar_  
!foo now returns "bar" again

### Randomize

**!rem = $rand(%)**  
creates a randomizer from all existing phrases “1”, “2”, “3”, and so on. Those have to be set first!  
_!rem foo = $rand(foo%)_

### Forget

You can also delete phrases (just the ones you set yourself).

**!forget**  
Deletes a stored phrase  
_!forget foo_

### Give

Once a phrase is set, you can “give” it to people. When you do that, the bot puts the name of the person you are giving it to in front of the phrase, thereby highlighting that person.

**!give**  
Gives a phrase to somebody  
_!give crshd foo_

### Find

If you think there’s a phrase, but can’t exactly remember the command, _find_ helps.

**!find**  
returns all phrases that are close  
_!find foo_

## Pokes

**!poke**  
Pokes nick with a random poke.  
_!poke crshd_

**!rempoke**  
Saves a poke. %s gets replaced with the poked user.  
_!rempoke pokes %s with a stick_

**!forgetpoke**  
Forgets a poke. Only the user who set the poke can delete it.  
_!forgetpoke pokes %s with a stick_

## Cookies

**!cookie**  
Gives a cookie to somebody  
_!cookie crshd_

## Weather

**!weather**  
Shows weather at stored location (need to store location first!)  
_!weather_

**!weather search**  
Searches for location code  
_!weather search new york_

**!weather save**  
Saves your location to the database  
_!weather save USNY0996_

**!weather forecast**  
Shows 5-day forecast. Uses stored location when no location specified.  
_!weather forecast_  
_!weather forecast USNY0996_

**!weather report**  
Shows current weather at location  
_!weather report USNY0996_

**!weather map**  
Shows link to weather map. Uses stored location when no location specified.  
_!weather map_  
_!weather map USNY0996_

**!weather convert**  
Converts temperature between °F and °C  
_!weather convert 96F_  
_!weather convert 35C_

## Non-User Controlled Functions

There’s also some functions that are not controlled by users

**URL titles**

When a URL is posted by somebody in the chat room, the bot displays the title of the page linked to.

**Submission notifications**

The bot checks PF periodically to see if something new has been submitted to pixelfuckers.org. If it finds something, it will display a notification in the chatroom, showing the submissions title, the user who submitted it, and the link to the submission.
