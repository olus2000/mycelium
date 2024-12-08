! Copyright (C) 2024 Aleksander Sabak.
! See https://factorcode.org/license.txt for BSD license.
USING: accessors arrays assocs assocs.extras combinators
continuations db.tuples debugger discord formatting hashtables
http http.client io.streams.string json kernel literals math
math.parser multiline mycelium.db namespaces sets sequences
sequences.extras splitting ;
IN: mycelium.common


CONSTANT: EPHEMERAL $[ 1 6 shift ]


ERROR: mycelium-error message ;


SYMBOL: last-opcode


HOOK: authored-by-admin? last-opcode ( -- ? )

M: MESSAGE_CREATE authored-by-admin?
  discord-bot get last-message>> obey-message? ;

M: INTERACTION_CREATE authored-by-admin?
  discord-bot get last-message>> [ "member" of ] keep or
  "user" of "username" of
  discord-bot-config get obey-names>> in? ;


: if-admin
  ( ..A then: ( ..A -- ..B ) else: ( ..A -- ..B ) -- ..B )
  authored-by-admin? -rot if ; inline


: when-admin ( ... quot: ( ... -- ... ) -- ... )
  authored-by-admin? swap when ; inline


: <discord-request> ( path method -- request )
  [ >discord-url ] dip <client-request>
  add-discord-auth-header ;


: message-payload-base ( string -- hashtable )
  "content" associate
  "allowed_mentions" H{ } set-of ;

: add-button ( hashtable -- hashtable' )
  discord-bot get last-message>> "id" of
  'H{ { "type" 2 }
      { "style" 2 }
      { "label" "Show" }
      { "custom_id" _ } } 1array
  'H{ { "type" 1 }
      { "components" _ } } 1array
  "components" swap set-of ;

HOOK: result-message* last-opcode ( string -- json )

M: MESSAGE_CREATE result-message*
  message-payload-base
  discord-bot get last-message>>
  [ "id" of "message_id" associate
    "message_reference" swap set-of ]
  [ "channel_id" of ] bi
  "/channels/%s/messages" sprintf discord-post-json ;

M: INTERACTION_CREATE result-message*
  message-payload-base add-button
  discord-bot-config get application-id>>
  discord-bot get last-message>> "token" of
  "/webhooks/%s/%s/messages/@original" sprintf
  discord-patch-json ;

: result-message ( string -- ) result-message* drop ;


HOOK: result-empty last-opcode ( -- )

M: MESSAGE_CREATE result-empty
  discord-bot get last-message>>
  [ "channel_id" of ] [ "id" of ] bi
  "/channels/%s/messages/%s/reactions/%%F0%%9F%%91%%8D/@me"
  sprintf "PUT" <discord-request> http-request 2drop ;

M: INTERACTION_CREATE result-empty
  "No output" result-message ;


: find-boundary ( message -- boundary )
  "\n" split [ "--" ?head ] filter-map*
  0 [ tuck 41 >base '[ _ head? ] any? ] with [ 1 + ] while
  41 >base ;

CONSTANT: file-form-data [[
Content-Disposition: form-data; name="files[0]";filename="result.txt"
Content-Type: text/plain; charset="UTF-8"

]]

CONSTANT: attachment-form-data [[
Content-Disposition: form-data; name="payload_json"
Content-Type: application/json

%s
--]]


: message>multipart-form ( content json -- payload boundary )
  >json over find-boundary
  [ [ file-form-data "\n--" surround "--" ] dip
    attachment-form-data sprintf rot "--\n" 4array ]
  dip [ join ] keep ;


: add-multipart-header ( request boundary -- request' )
  "multipart/form-data; boundary=\"%s\"" sprintf
  "Content-Type" set-header ;

HOOK: result-file* last-opcode ( message -- json )


M: MESSAGE_CREATE result-file*
  discord-bot get last-message>> tuck "id" of
  'H{ { "message_id" _ } }
  'H{ { "attachments" { H{ { "id" 0 } } } }
      { "message_reference" _ } }
  message>multipart-form
  rot "channel_id" of
  "/channels/%s/messages" sprintf "POST" <discord-request>
  swap add-multipart-header swap >>post-data json-request ;

M: INTERACTION_CREATE result-file*
  H{ { "attachments" { H{ { "id" 0 } } } } } clone add-button
  message>multipart-form
  discord-bot-config get application-id>>
  discord-bot get last-message>> "token" of
  "/webhooks/%s/%s/messages/@original" sprintf
  "PATCH" <discord-request>
  swap add-multipart-header swap >>post-data json-request ;


CONSTANT: MAX-FILE-SIZE $[ 1024 1024 25 * * ]
CONSTANT: MAX-MESSAGE-SIZE 2000


: sized-message* ( nonempty-string -- json )
  { { [ dup empty? ] [ drop result-empty f ] }
    { [ dup length MAX-MESSAGE-SIZE <= ]
      [ result-message* ] }
    { [ dup length MAX-FILE-SIZE <= ]
      [ result-file* ] } } cond ;


: response-message* ( string -- json )
  sized-message* dup "id" of
  discord-bot get last-message>> "id" of swap 0
  <command-response> [ insert-tuple ] with-mycelium-db ;

: response-message ( string -- ) response-message* drop ;


: try-handle-with
  ( ... command quot: ( ... command -- ... result )
  -- ... result? )
  [ [ print-error ] with-string-writer
    "```\n" dup surround nip ] recover ; inline
