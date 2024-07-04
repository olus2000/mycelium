================================================================================
                                    Mycelium
================================================================================


A personal discord bot by and for olus2000, written in Factor.

Requires Factor 0.99 (should also work on 0.100).

To run it yourself:

 - make sure you have Factor 0.99 installed

 - clone this repo to one of your vocabulary roots (if you don't know what that
   is you probably want it in the `work` folder in your Factor install
   directory)

 - copy the contents of ``sample-config`` directory to the ``config`` directory
   and fill out the data in ``config.factor`` with your bot's credentials

 - figure out a way to execute the ``ensure-mycelium-db`` word from the
   ``mycelium.db`` vocab somehow. This doesn't need the discord bot to be
   running so you can do this even from the listener

 - execute `factor -run=mycelium`

You may also try using Factor deploy functionality to compile it to a standalone
binary, but the bot uses a lot of functionality that you normally want to strip
away, like prettyprinting. The `eval` functionality relies on the parser and
vocabs being available at runtime, so that will just straight up not work in a
deployed binary.


Functionality
=============

It currently supports five-ish commands prefixed by ``:``:

``:help [<command>]``
  Prints help for the specified command, or for help itself if no command is
  specified.

``:roll <dice>``
  Rolls dice according to ``<dice>`` and presents sorted results and total sum
  of the rolls. ``<dice>`` can be multiple space-separated dice specifiers in
  the ``XdY`` format (indicating rolling a ``Y``-sided die ``X`` times).

``:echo <message>``
  A test command. The bot should respond with ``<message>``.

``:3`` and ``:>``
  Any message starting with either of these sent by the bot's "admin" (person in
  the ``obey-names`` field of the config) will cause the bot to respond with the
  other one of these.

``:`````
  Available only to the bot's "admin". Expects a full discord code block and
  exeutes code in that code block with some common vocabs loaded. Intended for
  bot administration and maintenance. **WARNING:** this command will execute on
  your machine with full access and all the context of your discord bot. You can
  break your machine or leak your bot's token using it.
