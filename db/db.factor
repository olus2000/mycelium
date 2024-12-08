! Copyright (C) 2024 Aleksander Sabak.
! See https://factorcode.org/license.txt for BSD license.
USING: calendar db db.sqlite db.tuples db.types io.backend
io.directories kernel literals sequences ;
IN: mycelium.db


CONSTANT: mycelium-db-path
  $[ "vocab:mycelium/config/db.sqlite" normalize-path ]


: with-mycelium-db ( ..a quot: ( ..a -- ..b ) -- ..b )
  mycelium-db-path <sqlite-db> swap with-db ; inline


TUPLE: command-response message-id response-id last-access type ;

: <command-response> ( message-id response-id type -- response )
  now swap command-response boa ;


command-response "RESPONSE"
{ { "message-id" "MESSAGE_ID" VARCHAR +user-assigned-id+ }
  { "response-id" "RESPONSE_ID" VARCHAR }
  { "last-access" "LAST_ACCESS" TIMESTAMP +not-null+ }
  { "type" "TYPE" INTEGER +not-null+ } } define-persistent


CONSTANT: mycelium-tables
  { command-response }


: ensure-mycelium-db ( -- )
  mycelium-db-path touch-file
  [ mycelium-tables ensure-tables ] with-mycelium-db ;

: recreate-mycelium-db ( -- )
  [ mycelium-tables [ recreate-table ] each ] with-mycelium-db ;
