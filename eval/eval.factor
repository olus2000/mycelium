! Copyright (C) 2024 Aleksander Sabak.
! See https://factorcode.org/license.txt for BSD license.
USING: eval io.streams.string kernel mycelium.common namespaces
parser
prettyprint sequences strings vocabs.parser ;
IN: mycelium.eval


SYMBOL: eval-accum

: `` ( string -- ) eval-accum get swap append! drop ;

: ``. ( obj -- ) [ . ] with-string-writer `` ;

: ``... ( obj -- ) [ ... ] with-string-writer `` ;

: with-`` ( ..a quot: ( ..a -- ..b ) -- ..b string )
  '[ @ eval-accum get >string ]
  V{ } clone eval-accum rot with-variable ; inline


CONSTANT: eval-vocabs
  { "accessors" "assocs" "combinators" "db.tuples" "discord"
    "kernel" "math" "namespaces" "sequences" "vocabs.loader" }


! Important to keep these in order in which they can be reloaded
CONSTANT: mycelium-vocabs
  { "mycelium.config" "mycelium.db" "mycelium.common"
    "mycelium.eval" "mycelium.roll" "mycelium.netrunner" "mycelium" }


: handle-``` ( user command -- response? )
  swap
  [ [ [ eval-vocabs [ use-vocab ] each
        mycelium-vocabs [ use-vocab ] each
        [ 3 head* ( -- ) (eval) ] with-`` ] with-file-vocabs ]
    try-handle-with ]
  [ drop f ] if-admin ;


