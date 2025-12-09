
def random_select($count; $ensure_in):
	if $count <= 0 or length <= 0 then []
	else
		. as $in
		| ( $ensure_in // {} ) as $ensure
		| ( if $ensure | length > 0 then
			[ foreach ($ensure | keys[]) as $k ({};
				( $ensure[$k] | .[ now * 1000000 % length ] ) as $kk | .[$k] = $kk ; .) ]
			| reverse
			else [] end ) as $ensure_selection
		| reduce $ensure_selection[] as $e ([];
			if length > 0 then . else [ $in[] | select(contains($e)) ] end)
		| if length > 0 then . else $in end
		| [ .[ now * 1000000 % length ] ] as $row
		| $row + (( $in - $row )
			| random_select($count - 1;
				[ ( $row[], $ensure_selection[-1] // {}) | to_entries[] ]
				| reduce .[] as $e ($ensure; if has($e.key) then .[$e.key] -= [ $e.value ] end)
				| del(.. | select(length < 1))
			)
			)
	end
;

[ $ARGS.positional[] as $i | { "key": $i, "value": .[$i] } ]
| from_entries as $ensure
| reduce .[] as $e ([{}]; [ .[] as $c | $e.value[] | $c + { ($e.key): . } ])
| map(select([$ARGS.named.exclude[] as $e | contains($e)] | any | not))
| random_select($ARGS.named.count // 4 | tonumber; $ensure)
| sort

