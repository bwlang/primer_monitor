#!/usr/bin/env bash

# recompute the primer data for igvjs visualization
set -e # fail on error

primer_monitor_path="$1"
organism_dirname="$2"
pct_cutoff="$3"
score_cutoff="$4"
cpus="$5"
primer_sets_file="$6"

if (($# > 6)); then
  # a file with a list of lineage groups to always show, one per line
  overrides_path="$7"
fi

if [ "$primer_sets_file" = "all" ]; then
  # unset the file if "all" is specified
  unset primer_sets_file
fi


echo "$(date +'%b %d %H:%M:%S') - primer recomputation started"



# unset any pre-existing value for JUMP_PROXY so unset == "don't use a jump proxy"
unset JUMP_PROXY

source "$primer_monitor_path/.env"
export DB_HOST
export DB_USER_RO
export DB_NAME
mkdir -p "$organism_dirname/config"
mkdir -p "$organism_dirname/lineage_sets"
mkdir -p "$organism_dirname/lineage_variants"
mkdir -p "$organism_dirname/primer_sets_bed"
mkdir -p "$organism_dirname/primer_sets_fasta"

scp_proxy()
{
  scp ${JUMP_PROXY:+"-o ProxyJump=$JUMP_PROXY"} "$@"
}

ssh_proxy()
{
  # shellcheck disable=SC2029
  # I actually want this expanded on the client side
  ssh ${JUMP_PROXY:+"-J $JUMP_PROXY"} "$@"
}

echo "$(date +'%b %d %H:%M:%S') - getting primer sets"

"$primer_monitor_path/lib/visualization/get_primer_sets.sh" "$organism_dirname/primer_sets_bed" "$organism_dirname/primer_sets_fasta" "$primer_sets_file" > "$organism_dirname/config/tracks.json"

echo "$(date +'%b %d %H:%M:%S') - done getting primer sets"

if [ -z "$primer_sets_file" ]; then
  echo "$(date +'%b %d %H:%M:%S') - performing full update"
  # if full update, recompute lineage sets
  echo "$(date +'%b %d %H:%M:%S') - getting all lineages"
  "$primer_monitor_path/lib/visualization/get_lineage_data.sh" > lineages.csv;

  echo "$(date +'%b %d %H:%M:%S') - getting daily seq counts"
  psql -h "$DB_HOST" -d "$DB_NAME" -U "$DB_USER_RO" -c "SELECT COALESCE(date_collected, date_submitted), COUNT(*) \
  FROM fasta_records GROUP BY COALESCE(date_collected, date_submitted);" --csv -t > seq_counts.csv

  echo "$(date +'%b %d %H:%M:%S') - calculating lineage groups of interest"
  curl -Ssf https://raw.githubusercontent.com/cov-lineages/pango-designation/master/pango_designation/alias_key.json \
  | python "$primer_monitor_path/lib/visualization/get_lineages_to_show.py" A,B lineages.csv seq_counts.csv "$organism_dirname/lineage_sets" > "$organism_dirname/config/lineage_sets.json" "$overrides_path"
  echo "$(date +'%b %d %H:%M:%S') - done calculating lineage groups"
else
  echo "$(date +'%b %d %H:%M:%S') - performing partial update"
  # download existing lineage sets from the data server
  echo "$(date +'%b %d %H:%M:%S') - downloading lineage data"
  scp_proxy -r "$FRONTEND_HOST:$IGVSTATIC_PATH/$organism_dirname/lineage_sets" "./$organism_dirname";
  scp_proxy -r "$FRONTEND_HOST:$IGVSTATIC_PATH/$organism_dirname/config/lineage_sets.json" "./$organism_dirname/config/lineage_sets.json";
  echo "$(date +'%b %d %H:%M:%S') - lineage data downloaded"
fi


echo "$(date +'%b %d %H:%M:%S') - getting list of primer sets to process"
if [ -z "$primer_sets_file" ]; then
  find "$organism_dirname/primer_sets_bed" -name '*.bed' -exec basename -a "{}" + > primer_sets_data.txt
else
  while read -r primer_set; do
    echo "$("$(dirname "$0")/urlify_name.sh" "$primer_set").bed" >> primer_sets_data.txt;
  done < "$primer_sets_file"
fi

echo "$(date +'%b %d %H:%M:%S') - recomputing overlaps"
cat <(ls "$organism_dirname/lineage_sets") <(echo "all.txt") \
| xargs "$primer_monitor_path/lib/visualization/process_primer_sets_with_lineages.sh" - "./$organism_dirname" "$pct_cutoff" "$score_cutoff" \
primer_sets_data.txt "./$organism_dirname" "$cpus"

rm primer_sets_data.txt

if [ -z "$primer_sets_file" ]; then
  # if full update, remove old files so this doesn't clutter up the directories
  echo "$(date +'%b %d %H:%M:%S') - removing old files"
  ssh_proxy "$FRONTEND_HOST" "rm -rf $IGVSTATIC_PATH/$organism_dirname/primer_sets; \
  rm -f $IGVSTATIC_PATH/$organism_dirname/primer_sets_bed/* $IGVSTATIC_PATH/$organism_dirname/lineage_sets/* \
  $IGVSTATIC_PATH/$organism_dirname/lineage_variants/* $IGVSTATIC_PATH/$organism_dirname/primer_sets_fasta/*;"

  echo "$(date +'%b %d %H:%M:%S') - uploading new data"
  # copies over the new files
  # the * is intentionally not quoted so globbing works
  scp_proxy -r "./$organism_dirname/"* "$FRONTEND_HOST:$IGVSTATIC_PATH/$organism_dirname/";

else
  # copies over only the files changed for the new primer
  echo "$(date +'%b %d %H:%M:%S') - uploading new data"
  while read -r primer_set; do
    urlified_primer_set_name=$("$(dirname "$0")/urlify_name.sh" "$primer_set")
    scp_proxy -r "./$organism_dirname/config/tracks.json" "$FRONTEND_HOST:$IGVSTATIC_PATH/$organism_dirname/config/tracks.json";
    scp_proxy -r "./$organism_dirname/primer_sets_bed/${urlified_primer_set_name}.bed" "$FRONTEND_HOST:$IGVSTATIC_PATH/$organism_dirname/primer_sets_bed/${urlified_primer_set_name}.bed";
    scp_proxy -r "./$organism_dirname/primer_sets_fasta/${urlified_primer_set_name}.fasta" "$FRONTEND_HOST:$IGVSTATIC_PATH/$organism_dirname/primer_sets_fasta/${urlified_primer_set_name}.fasta";
    scp_proxy -r "./$organism_dirname/primer_sets_status/${urlified_primer_set_name}" "$FRONTEND_HOST:$IGVSTATIC_PATH/$organism_dirname/primer_sets";
  done  < "$primer_sets_file"
fi

echo "$(date +'%b %d %H:%M:%S') - done"