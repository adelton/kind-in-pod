
# Get values from environment variables
# or go with defaults from job.workflow_file_path

with_entries(
	select(.value.type == "choice")
	| $ENV[.key | ascii_upcase | gsub("-"; "_")] as $e
	| ( if $e == "" then .value.options[0] else $e end ) as $e
	| if $e == "none" then
		.value = []
	elif $e == "both" or $e == "all" then
		.value = [ .value.options[] | . as $v | select(all("both", "all", "none"; . != $v)) ]
	else
		.value = [ $e ]
	end
)
