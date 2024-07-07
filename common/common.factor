! Copyright (C) 2024 Aleksander Sabak.
! See https://factorcode.org/license.txt for BSD license.
USING: accessors arrays assocs combinators continuations
db.tuples debugger discord formatting hashtables http
http.client io.streams.string kernel literals math math.parser
multiline mycelium.db namespaces splitting sequences
sequences.extras ;
IN: mycelium.common


ERROR: mycelium-error message ;


: if-admin
  ( ..A then: ( ..A -- ..B ) else: ( ..A -- ..B ) -- ..B )
  discord-bot get last-message>> obey-message? -rot if ; inline


: <discord-request> ( path method -- request )
  [ >discord-url ] dip <client-request>
  add-discord-auth-header ;


: when-admin ( ... quot: ( ... -- ... ) -- ... )
  discord-bot get last-message>>
  obey-message? swap when ; inline


: response-react ( -- )
  discord-bot get last-message>>
  [ "channel_id" of ] [ "id" of ] bi
  "/channels/%s/messages/%s/reactions/%%F0%%9F%%91%%8D/@me"
  sprintf "PUT" <discord-request> http-request 2drop ;


: response-message* ( string -- json )
  discord-bot get last-message>>
  [ "id" of "message_id" associate
    "message_reference" associate
    "content" rot set-of
    "allowed_mentions" H{ } set-of ]
  [ "channel_id" of ] bi
  "/channels/%s/messages" sprintf discord-post-json ;

: response-message ( string -- ) response-message* drop ;


: find-boundary ( message -- boundary )
  "\n" split [ "--" ?head ] filter-map*
  0 [ tuck 41 >base '[ _ head? ] any? ] with [ 1 + ] while
  41 >base ;

CONSTANT: file-form-data [[
Content-Disposition: form-data; name="files[0]"; filename="response.txt"
Content-Type: text/plain; charset="UTF-8"

]]

CONSTANT: attachment-form-data [[
Content-Disposition: form-data; name="payload_json"
Content-Type: application/json

{"attachments":[{"id":0}],"message_reference":{"message_id":"%s"},"allowed_mentions":{}}
--]]

: message>multipart-form ( message -- payload boundary )
  dup find-boundary
  [ file-form-data "\n--" surround
    "--" discord-bot get last-message>> "id" of
    attachment-form-data sprintf rot "--\n" 4array ]
  dip [ join ] keep ;

: response-file* ( message -- json )
  message>multipart-form over g...
  discord-bot get last-message>> "channel_id" of
  "/channels/%s/messages" sprintf "POST" <discord-request>
  swap "multipart/form-data; boundary=\"%s\"" sprintf
  "Content-Type" set-header swap >>post-data json-request ;



CONSTANT: MAX-FILE-SIZE $[ 1024 1024 25 * * ]
CONSTANT: MAX-MESSAGE-SIZE 2000

: interaction-message* ( string -- json )
  { { [ dup empty? ] [ drop response-react f f ] }
    { [ dup length MAX-MESSAGE-SIZE <= ]
      [ response-message* dup "id" of ] }
    { [ dup length MAX-FILE-SIZE <= ]
      [ response-file* dup "id" of ] } } cond
  discord-bot get last-message>> "id" of swap 0 <interaction>
  [ insert-tuple ] with-mycelium-db ;

: interaction-message ( string -- )
  interaction-message* drop ;


: try-handle-with
  ( ... command quot: ( ... command -- ... response )
  -- ... response? )
  [ [ print-error ] with-string-writer
    "```\n" dup surround nip ] recover ; inline
