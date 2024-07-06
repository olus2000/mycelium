! Copyright (C) 2024 Aleksander Sabak.
! See https://factorcode.org/license.txt for BSD license.
USING: accessors assocs combinators continuations db.tuples
debugger discord formatting http.client kernel multiline
mycelium.common mycelium.config mycelium.db mycelium.eval
mycelium.roll namespaces sequences splitting threads ;
IN: mycelium


CONSTANT: echo-help [[
Usage: `:echo <message>`

Replies with `<message>`.
]]

CONSTANT: help-help [[
Usage: `:help [<command>]`

Replies with help on a given command. Avaliable commands:
* help - you're using it right now
* echo - echo
* roll - rolls dice
]]


: handle-help ( command -- reponse? )
  split-words harvest [ help-help ]
  [ first
    { { "echo" [ echo-help ] }
      { "help" [ help-help ] }
      { "roll" [ roll-help ] }
      [ drop help-help ] } case ] if-empty ;


: handle-command ( command -- response? )
  ":" ?head
  [ { { [ "echo" ?head ] [ ] }
      { [ "help" ?head ] [ handle-help ] }
      { [ "roll" ?head ] [ handle-roll ] }
      { [ "3" ?head ]
        [ drop [ ":>" ] [ f ] if-admin ] }
      { [ ">" ?head ]
        [ drop [ ":3" ] [ f ] if-admin ] }
      { [ "```" ?head ] [ handle-``` ] }
      [ drop f ] } cond ]
  [ drop f ] if ;


GENERIC: mycelium-handler ( json opcode -- )

M: object mycelium-handler 2drop ;

M: MESSAGE_CREATE mycelium-handler
  drop dup "author" of "bot" of [ drop ]
  [ "content" of
    [ handle-command [ interaction-message ] when* ]
    [ [ print-error ] with-global drop ] recover ] if ;

M: MESSAGE_DELETE mycelium-handler
  drop interaction new over "id" of >>message-id
  [ select-tuple ] with-mycelium-db
  [ dup [ delete-tuples ] with-mycelium-db
    [ "channel_id" of ] [ response-id>> ] bi*
    [ "/channels/%s/messages/%s" sprintf
!     discord-delete-request ! This was added in 0.100
      "DELETE" <discord-request> http-request 2drop ]
    [ drop ] if* ]
  [ drop ] if* ;


: run-mycelium ( -- )
  mycelium-config
  [ mycelium-handler ] >>user-callback
  discord-connect ;


: main ( -- ) run-mycelium "Running mycelium" suspend drop ;


MAIN: main
