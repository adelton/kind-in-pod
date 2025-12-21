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

flatten
| . as $data
| reduce .[] as $r ({}; .[ $r["inner-podman-version"] ][ $r.arch ] = 1)
| with_entries( .value = ( .value | keys | sort ) )
| . as $dist
| $data
| reduce .[] as $r ({};
	if ($r | has("podman-style")) then
		.["podman"][ $r["podman-style"] ][ $r["inner-podman-version"] ][ $r.arch ] = "🔷"
	else
		.["k3s"][ $r["runtime"] ][ $r["inner-podman-version"] ][ $r.arch ] = "🔷"
	end)
| . as $data
|

"<table>",
"  <thead>",

"    <tr>",
( "Environment" | th(3; 1) ),
( "Runtime" | th(3; 1) ),
( "Podman in the pod" | th(1; [ $dist | to_entries | .[] | .value | length ] | add ) ),
"    </tr>",
"    <tr>",
( $dist | keys | sort | .[] | th(1; $dist[.] | length) ),
"    </tr>",
"    <tr>",
( $dist | keys | sort | .[] | $dist[.][] | th(1; 1) ),
"    </tr>",

"  </thead>",
"  <tbody>",

( $data | to_entries[]
	| .key as $k
	| .value | to_entries | sort_by(.key)
	| . as $v
	| ( "    <tr>",
		( $k | th( $v | length; 1) ),
			( $v | .[0].key as $first_key | .[] | .value as $v
				| ( if .key != $first_key then "    <tr>" else empty end ),
				( .key | th(1; 1),
					( $dist | to_entries | .[] | .key as $k | .value[]
						| [ $k, . ] as $p | $v | getpath($p) | td(1))
				),
				"    </tr>"
			)
		)
	),

"  </tbody>",
"</table>"
