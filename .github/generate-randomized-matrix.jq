
def xcontains($element):
	. as $input |
	$element | to_entries | map($input[.key] == .value) | all
;

def unseen:
	[ (.c1 | length), (.c2 | length) ]
;

[ [ $ARGS.positional[] as $i | [ .[$i][] | { $i: . } ] ]
	| combinations
	| add
]
| map(select([$ARGS.named.exclude[]? as $e | xcontains($e)] | any | not))

| [ .[]
	| ( [ to_entries[] | [.] | from_entries ] ) as $c1
	| {
		r: .,
		c1: $c1,
		c2: [ $c1 | range(0; length) as $i | range($i + 1; length) as $j | [.[$i], .[$j]] ]
	}
]

| [
try
foreach range($ARGS.named.count // 4 | tonumber) as $n (.;
	if $n >= length then error("no more contributing records left at \($n)") end

	| ( if $n == 0 then [ range(length) ]
		else ( .[$n:] | map(unseen) | max ) as $max
			| [ range($n; length) as $i | select((.[$i] | unseen) == $max) | $i ]
		end ) as $list

	| $list[ now * 1000000 % ($list | length) ] as $selected_index
	| .[$selected_index] as $selected
	| .[$selected_index] = .[$n]
	| .[$n] = $selected

	| reduce range($n + 1; length) as $i (.;
		.[$i].c1 -= $selected.c1
		| .[$i].c2 -= $selected.c2
	)
	;
	.[$n].r
)
catch ( debug(. // "unspecified error") | empty )
]

| sort_by(.[])

