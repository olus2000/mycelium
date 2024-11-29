! Copyright (C) 2024 Your name.
! See https://factorcode.org/license.txt for BSD license.
USING: assocs http.json interpolate kernel multiline
mycelium.common sequences urls ;
IN: mycelium.netrunner


CONSTANT: card-help [[
USAGE: `:card <name>`

Searches netrunnerdb.com for a card using the query specified in `<name>`.
The query can contain more involved nrdb-like syntax but only one card will be returned, so it's most useful for searching up specific cards.
Returns a link to the image of the found card or an error message if no card was found.
Uses https://api-preview.netrunnerdb.com/api/docs/#cards-filter___card_search_operator
]]


CONSTANT: nrdb-card-query
URL"https://api-preview.netrunnerdb.com/api/v3/public/printings?filter[distinct_cards]=true&page[size]=1"


: >nrdb-search-url ( query -- url )
  nrdb-card-query swap "filter[search]" set-query-param ;


: ?json>card-image ( json -- url|error-message )
  "data" of [ "No cards found." ]
  [ first "attributes" of "images" of "nrdb_classic" of
    "large" of ] if-empty ;


: handle-card ( message -- response? )
  [ >nrdb-search-url http-get-json nip ?json>card-image ]
  try-handle-with ;
