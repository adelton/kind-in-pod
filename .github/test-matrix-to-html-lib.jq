def th($rowspan; $colspan):
	"      " + "<th"
		+ (if $rowspan > 1 then " rowspan=\"" + ($rowspan | tostring) + "\"" else "" end)
		+ (if $colspan > 1 then " colspan=\"" + ($colspan | tostring) + "\"" else "" end)
		+ ">"
		+ .
		+ "</th>"
;

def td($rowspan):
	"      " + "<td"
		+ (if $rowspan > 1 then " rowspan=\"" + ($rowspan | tostring) + "\"" else "" end)
		+ ">"
		+ .
		+ "</td>"
;

def table($title; $coltitles):

	. as $data

| ( $coltitles | length ) as $ncolstart

# fetch the top data (the rows in the table)
| ( [ paths | select(length == $ncolstart) ]
	| reduce .[] as $p ({}; getpath($p) //= {}) ) as $rows
# and .spans for the rows
| ( $rows | walk(.[".span"] = ([ .[][".span"]? ] | add // 1)) ) as $rowspans

# set the columns
| ( [ paths | select(length > $ncolstart) | .[$ncolstart:] ]
	| sort
	| reduce .[] as $p ({}; getpath($p) //= {}) ) as $cols
# and .spans for the columns
| ( $cols | walk(.[".span"] = ([ .[][".span"]? ] | add // 1)) ) as $colspans
| ( [ $cols | paths | length ] | max ) as $colsmax

|

"<table>",
"  <thead>",

"    <tr>",
( $coltitles[] | th($colsmax + 1; 1) ),
( $title | th(1; $colspans[".span"]) ),
"    </tr>",

( range(1; $colsmax + 1)
	|
	"    <tr>",
	. as $r
	| ( $cols | paths | select(length == $r) | . as $p | .[-1] | th(1; $colspans | getpath($p + [".span"])) ),
	"    </tr>"
),

"  </thead>",
"  <tbody>",

( [ $rows | paths ] | foreach .[] as $p ([[], []];
	[ .[1], $p ];
	if (.[0] | length) == 0 or (.[0] | length) >= ($p | length) then "    <tr>" else empty end,
	( $p[-1] | th($rowspans | getpath($p + [".span"]); 1)),
	if ($p | length) == $ncolstart
	then ( $data | getpath( $cols | paths | select(length == $colsmax) | ($p + .)) | td(1)),
		"    </tr>"
	else empty end
	)),

"  </tbody>",
"</table>"

;
