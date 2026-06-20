
import "test-matrix-to-html-lib" as matrix_to_html;

flatten
| sort_by(if .["podman-style"] then 0 else 1 end, .kubernetes, .runtime)
| reduce .[] as $r ({};
	if ($r | has("podman-style")) then
		.["podman"][ $r["podman-style"] ][ $r["inner-podman-version"] ][ $r.arch ] = "🔷"
	else
		.[ $r.kubernetes ][ $r.runtime ][ $r["inner-podman-version"] ][ $r.arch ] = "🔷"
	end)

| matrix_to_html::table("Podman in the pod"; [ "Environment", "Runtime" ])

