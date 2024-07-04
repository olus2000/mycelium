! Copyright (C) 2024 Aleksander Sabak.
! See https://factorcode.org/license.txt for BSD license.
USING: accessors assocs continuations db.tuples debugger discord
formatting hashtables
io.streams.string kernel mycelium.db namespaces sequences ;
IN: mycelium.common


: if-admin
  ( ..A then: ( ..A -- ..B ) else: ( ..A -- ..B ) -- ..B )
  discord-bot get last-message>> obey-message? -rot if ; inline


: when-admin ( ... quot: ( ... -- ... ) -- ... )
  discord-bot get last-message>>
  obey-message? swap when ; inline


: response-message* ( string -- json )
  discord-bot get last-message>>
  [ "id" of "message_id" associate
    "message_reference" associate
    "content" rot set-of
    "allowed_mentions" H{ } set-of ]
  [ "channel_id" of ] bi
  "/channels/%s/messages" sprintf discord-post-json ;

: response-message ( string -- ) response-message* drop ;


: interaction-message* ( string interaction-type -- json )
  [ response-message* dup "id" of ] dip
  discord-bot get last-message>> "id" of -rot <interaction>
  [ insert-tuple ] with-mycelium-db ;

: interaction-message ( string -- )
  0 interaction-message* drop ;


: try-handle-with
  ( ... command quot: ( ... command -- ... response )
  -- ... response sender )
  [ [ print-error ] with-string-writer
    "```\n" dup surround nip ]
  recover [ interaction-message ] ; inline
