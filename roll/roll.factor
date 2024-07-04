! Copyright (C) 2024 Aleksander Sabak.
! See https://factorcode.org/license.txt for BSD license.
USING: accessors ascii continuations debugger discord grouping
io.streams.string kernel math math.order math.parser multiline
mycelium.common peg random ranges sequences sequences.extras
sorting strings ;
IN: mycelium.roll


CONSTANT: roll-help [[
Usage: `:roll <dice>`

Rolls dice specified in `<dice>` and returns sorted results and a total.
`<dice>` should be space-separated dice descriptions in the `XdY` format.
]]


CONSTANT: max-dice-count 10000

ERROR: too-many-dice total max ;

: check-max-die-count ( dices -- dices )
  dup 0 [ count>> + ] reduce max-dice-count
  2dup > [ too-many-dice ] [ 2drop ] if ;


TUPLE: dice count sides ;

: <dice> ( count? sides -- dice ) [ 1 or ] dip dice boa ;

: roll ( dice -- results )
  [ count>> ] [ sides>> ] bi '[ _ random 1 + ] replicate ;


: space-parser ( -- parser ) [ " \r\n\t" member? ] satisfy ;


! Idk why `digit?` produces nice errors but not `1 9 between?`
: integer-parser ( -- parser )
  CHAR: 1 CHAR: 9 [a..b] [ 1string token ] map choice
  [ digit? ] satisfy repeat0 2seq
  [ first2 append string>number ] action ;

: dice-parser ( -- parser )
  integer-parser optional "d" token hide integer-parser 3seq
  [ first2 <dice> ] action ;

PEG: parse-roll ( string -- dices )
  space-parser repeat0 hide dice-parser
  space-parser repeat1 hide dice-parser 2seq repeat0
  3seq [ first2 swap prefix ] action ;


! EBNF: parse-roll [=[
! space = [ \r\n\t]
! 
! number = [1-9] [0-9]* => [[ first2 swap prefix string>number ]]
! 
! dice = number? "d"~ number => [[ first2 <dice> ]]
! 
! roll = (space*)~ dice ((space+)~ dice)*
!      => [[ first2 swap prefix ]]
! ]=]


: run-roll ( dices -- string )
  check-max-die-count
  [ roll ] map-concat sort
  [ 10 <groups> [ [ number>string ] map " " join ] map
    "\n" join "```\n" dup surround ]
  [ sum number>string "Total: " prepend ] bi
  [ append ] keep over length 2000 > [ nip ] [ drop ] if ;


: handle-roll ( message -- response sender )
  [ parse-roll run-roll ] try-handle-with ;
