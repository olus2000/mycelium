! Copyright (C) 2024 Aleksander Sabak.
! See https://factorcode.org/license.txt for BSD license.
USING: accessors assocs combinators continuations db.tuples
debugger discord formatting http.client json kernel literals
math multiline mycelium.common mycelium.config mycelium.db
mycelium.eval mycelium.netrunner mycelium.roll namespaces
sequences splitting threads ;
IN: mycelium


: register-mycelium-message-command ( -- json )
  H{ { "name" "Run" }
     { "type" 3 }
     { "integration_types" { 0 1 } } } mycelium-config
  [ application-id>> ] keep discord-bot-config
  [ set-discord-application-commands ] with-variable ;


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
* card - displays netrunner cards
]]


: handle-help ( user command -- reponse? )
  nip split-words harvest [ help-help ]
  [ first
    { { "echo" [ echo-help ] }
      { "help" [ help-help ] }
      { "roll" [ roll-help ] }
      { "card" [ card-help ] }
      [ drop help-help ] } case ] if-empty ;


: handle-command ( user command -- response? )
  ":" ?head
  [ { { [ "echo" ?head ] [ nip ] }
      { [ "help" ?head ] [ handle-help ] }
      { [ "roll" ?head ] [ handle-roll ] }
      { [ "card" ?head ] [ handle-card ] }
      { [ "3" ?head ]
        [ drop [ ":>" ] [ f ] if-admin ] }
      { [ ">" ?head ]
        [ drop [ ":3" ] [ f ] if-admin ] }
      { [ "```" ?head ] [ handle-``` ] }
      [ 2drop f ] } cond ]
  [ 2drop f ] if ;


GENERIC: mycelium-handler ( json opcode -- )

M: object mycelium-handler 2drop ;

M: MESSAGE_CREATE mycelium-handler
  drop dup "author" of dup "bot" of [ 2drop ]
  [ "username" of swap "content" of
    [ handle-command [ interaction-message ] when* ]
    [ [ print-error ] with-global 2drop ] recover ] if ;

M: MESSAGE_DELETE mycelium-handler
  drop interaction new over "id" of >>message-id
  [ select-tuple ] with-mycelium-db
  [ dup [ delete-tuples ] with-mycelium-db
    [ "channel_id" of ] [ response-id>> ] bi*
    [ "/channels/%s/messages/%s" sprintf
      discord-delete-request http-request 2drop ]
    [ drop ] if* ]
  [ drop ] if* ;

M: INTERACTION_CREATE mycelium-handler
  ! Instantly respond to the interaction with loading
  drop dup [ "id" of ] [ "token" of ] bi
  "/interactions/%s/%s/callback" sprintf
  H{ { "type" 5 } } >json swap
  discord-post-request add-json-header http-request 2drop
  ! Actually calculate the interaction response
  [ [ "member" of ] keep or "user" of "username" of ]
  [ "data" of "resolved" of "messages" of values first
    "content" of ] bi handle-command 'H{ { "content" _ } }
  ! Edit the response to include the actual content
  discord-bot-config get application-id>>
  discord-bot get last-message>> "token" of
  "/webhooks/%s/%s/messages/@original" sprintf
  discord-patch-json drop ;


: run-mycelium ( -- )
  mycelium-config
  [ mycelium-handler ] >>user-callback
  discord-connect ;


: main ( -- ) run-mycelium "Running mycelium" suspend drop ;


MAIN: main
