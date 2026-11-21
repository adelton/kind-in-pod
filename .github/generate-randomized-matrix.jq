
def xcontains($element):
	. as $input |
	$element | to_entries | map($input[.key] == .value) | all
;

def unseen:
	[ (.singles | length), (.pairs | length) ]
;

[ [ $ARGS.positional[] as $i | [ .[$i][] | { $i: . } ] ]
	| combinations
	| add
]
| map(select([$ARGS.named.exclude[]? as $e | xcontains($e)] | any | not))

| [ .[]
	| ( [ to_entries[] | [.] | from_entries ] ) as $singles
	| {
		r: .,
		singles: $singles,
		pairs: [ $singles | range(0; length) as $i | range($i + 1; length) as $j | [.[$i], .[$j]] ]
	}
]

| ( $ARGS.named.count // 4 | tonumber ) as $count
| ( $ARGS.named.seed // 42 | tonumber ) as $seed
| [ limit($count + 1; $seed % 2147483646 + 1 | recurse(. * 48271 % 2147483647)) ][1:] as $random
| if $count > length then debug("There are only \(length) input records, not \($count)") end
| reduce range([ $count, length ] | min) as $n (.;
	( if $n == 0 then [ range(length) ]
		else ( .[$n:] | map(unseen) | max ) as $max
			| [ range($n; length) as $i | select((.[$i] | unseen) == $max) | $i ]
		end ) as $list

	| $list[ $random[$n] % ($list | length) ] as $selected_index
	| .[$selected_index] as $selected
	| .[$selected_index] = .[$n]
	| .[$n] = $selected

	| reduce range($n + 1; length) as $i (.;
		.[$i].singles -= $selected.singles
		| .[$i].pairs -= $selected.pairs
	)
)
| .[:$count]
| map(.r)
| sort_by(.[])

