#!/usr/bin/env bash

# recompute the primer data for igvjs visualization
set -e # fail on error

primer_monitor_path="$1"
organism_dirname="$2"
pct_cutoff="$3"
score_cutoff="$4"
cpus="$5"
full_update="true";
if (($# > 5)); then
  # a file with a list of primer set names to update, one per line
  primer_sets_file="$6"
  full_update="false"
fi

# unset any pre-existing value for JUMP_PROXY so unset == "don't use a jump proxy"
unset JUMP_PROXY

source "$primer_monitor_path/.env"
export DB_HOST
export DB_USER_RO
export DB_NAME
mkdir -p "$organism_dirname/config"
mkdir -p "$organism_dirname/lineage_sets"
mkdir -p "$organism_dirname/lineage_variants"
mkdir -p "$organism_dirname/primer_sets_raw"

scp_proxy()
{
  scp ${JUMP_PROXY:+"-o"} ${JUMP_PROXY:+"ProxyJump=$JUMP_PROXY"} "$@"
}

ssh_proxy()
{
  # shellcheck disable=SC2029
  # I actually want this expanded on the client side
  ssh ${JUMP_PROXY:+"-J"} "${JUMP_PROXY:-''}" "$@"
}

"$primer_monitor_path/lib/visualization/get_primer_sets.sh" "$organism_dirname/primer_sets_raw" > "$organism_dirname/config/tracks.json"

if [ "$full_update" = true ]; then
  # if full update, recompute lineage sets
  "$primer_monitor_path/lib/visualization/get_lineage_data.sh" > lineages.csv;

  psql -h "$DB_HOST" -d "$DB_NAME" -U "$DB_USER_RO" -c "SELECT COALESCE(date_collected, date_submitted), COUNT(*) \
  FROM fasta_records GROUP BY COALESCE(date_collected, date_submitted);" --csv -t > seq_counts.csv

  curl https://raw.githubusercontent.com/cov-lineages/pango-designation/master/pango_designation/alias_key.json \
  | python "$primer_monitor_path/lib/visualization/get_lineages_to_show.py" A,B lineages.csv seq_counts.csv "$organism_dirname/lineage_sets"

  cat <(printf "{") <(find "$organism_dirname/lineage_sets" -exec basename -a "{}" + \
  | sed -E 's/^(.*)\\.txt$/"\\1": "\\1.*",/') <(echo '"all": "All"}') > "$organism_dirname/config/lineage_sets.json"
else
  # download existing lineage sets from the data server
  scp_proxy -r "$FRONTEND_HOST:$IGVSTATIC_PATH/$organism_dirname/lineage_sets" "./$organism_dirname/lineage_sets";
  scp_proxy -r "$FRONTEND_HOST:$IGVSTATIC_PATH/$organism_dirname/config/lineage_sets.json" "./$organism_dirname/config/lineage_sets.json";
fi

if [ "$full_update" = true ]; then
  echo "$organism_dirname/primer_sets_raw" > primer_sets_data.txt
else
  while read -r primer_set; do
    echo "$organism_dirname/primer_sets_raw/$("$(dirname "$0")/urlify_name.sh" "$primer_set").bed" >> primer_sets_data.txt;
  done < "$primer_sets_file"
fi

cat <(ls "$organism_dirname/lineage_sets") <(echo "all.txt") \
| xargs "$primer_monitor_path/lib/visualization/process_primer_sets_with_lineages.sh" - "./$organism_dirname" "$pct_cutoff" "$score_cutoff" \
primer_sets_data.txt "./$organism_dirname" "$cpus"

rm primer_sets_data.txt


if [ "$full_update" = true ]; then
  # if full update, remove old files so this doesn't clutter up the directories
  ssh_proxy "$FRONTEND_HOST" "rm -rf $IGVSTATIC_PATH/$organism_dirname/primer_sets; \
  rm -f $IGVSTATIC_PATH/$organism_dirname/primer_sets_raw/* $IGVSTATIC_PATH/$organism_dirname/lineage_sets/* \
  $IGVSTATIC_PATH/$organism_dirname/lineage_variants/*;"
fi

# copies over the new files
scp_proxy -r "./$organism_dirname/*" "$FRONTEND_HOST:$IGVSTATIC_PATH/$organism_dirname/";