! Copyright (C) 2024 Aleksander Sabak.
! See https://factorcode.org/license.txt for BSD license.
USING: accessors arrays assocs assocs.extras combinators
continuations db.tuples debugger discord formatting hashtables
http http.client io.streams.string kernel literals math
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

HOOK: response-message* last-opcode ( string -- json )

M: MESSAGE_CREATE response-message*
  message-payload-base
  discord-bot get last-message>>
  [ "id" of "message_id" associate
    "message_reference" swap set-of ]
  [ "channel_id" of ] bi
  "/channels/%s/messages" sprintf discord-post-json ;

M: INTERACTION_CREATE response-message*
  message-payload-base
  discord-bot-config get application-id>>
  discord-bot get last-message>> "token" of
  "/webhooks/%s/%s/messages/@original" sprintf
  discord-patch-json ;

: response-message ( string -- ) response-message* drop ;


HOOK: response-empty last-opcode ( -- )

M: MESSAGE_CREATE response-empty
  discord-bot get last-message>>
  [ "channel_id" of ] [ "id" of ] bi
  "/channels/%s/messages/%s/reactions/%%F0%%9F%%91%%8D/@me"
  sprintf "PUT" <discord-request> http-request 2drop ;

M: INTERACTION_CREATE response-empty
  "No output" response-message ;


: find-boundary ( message -- boundary )
  "\n" split [ "--" ?head ] filter-map*
  0 [ tuck 41 >base '[ _ head? ] any? ] with [ 1 + ] while
  41 >base ;

CONSTANT: file-form-data [[
Content-Disposition: form-data; name="files[0]"; filename="response.txt"
Content-Type: text/plain; charset="UTF-8"

]]

CONSTANT: (attachment-form-data-message) [[
Content-Disposition: form-data; name="payload_json"
Content-Type: application/json

{"attachments":[{"id":0}],"message_reference":{"message_id":"%s"},"allowed_mentions":{}}
--]]

CONSTANT: (attachment-form-data-interaction) [[
Content-Disposition: form-data; name="payload_json"
Content-Type: application/json

{"attachments":[{"id":0}],"allowed_mentions":{}}
--]]

HOOK: attachment-form-data last-opcode ( -- string )

M: MESSAGE_CREATE attachment-form-data
  discord-bot get last-message>> "id" of
  (attachment-form-data-message) sprintf ;

M: INTERACTION_CREATE attachment-form-data
  (attachment-form-data-interaction) ;

: message>multipart-form ( message -- payload boundary )
  dup find-boundary
  [ file-form-data "\n--" surround
    "--" attachment-form-data rot "--\n" 4array ]
  dip [ join ] keep ;


: add-multipart-header ( request boundary -- request' )
  "multipart/form-data; boundary=\"%s\"" sprintf
  "Content-Type" set-header ;

HOOK: response-file* last-opcode ( message -- json )

M: MESSAGE_CREATE response-file*
  message>multipart-form
  discord-bot get last-message>> "channel_id" of
  "/channels/%s/messages" sprintf "POST" <discord-request>
  swap add-multipart-header swap >>post-data json-request ;

M: INTERACTION_CREATE response-file*
  message>multipart-form
  discord-bot-config get application-id>>
  discord-bot get last-message>> "token" of
  "/webhooks/%s/%s/messages/@original" sprintf
  "PATCH" <discord-request>
  swap add-multipart-header swap >>post-data json-request ;


CONSTANT: MAX-FILE-SIZE $[ 1024 1024 25 * * ]
CONSTANT: MAX-MESSAGE-SIZE 2000


: sized-message* ( nonempty-string -- json )
  { { [ dup empty? ] [ drop response-empty f ] }
    { [ dup length MAX-MESSAGE-SIZE <= ]
      [ response-message* ] }
    { [ dup length MAX-FILE-SIZE <= ]
      [ response-file* ] } } cond ;


: interaction-message* ( string -- json )
  sized-message* dup "id" of
  discord-bot get last-message>> "id" of swap 0 <interaction>
  [ insert-tuple ] with-mycelium-db ;

: interaction-message ( string -- )
  interaction-message* drop ;


: try-handle-with
  ( ... command quot: ( ... command -- ... response )
  -- ... response? )
  [ [ print-error ] with-string-writer
    "```\n" dup surround nip ] recover ; inline
