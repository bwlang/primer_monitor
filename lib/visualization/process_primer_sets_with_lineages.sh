#!/usr/bin/env bash

cutoff_date="$1";
output_path="$2";
min_pct="$3";
score_cutoff="$4";
primer_sets_list_path="$5";
threads="$6"

echo "$(date +'%b %d %H:%M:%S') - script started"

if [[ $cutoff_date == '-' ]]; then # default of 180 days
  cutoff_date="$(date -d "180 days ago" +"%Y-%m-%d")"
fi

variants_bed="$$_variants.bed"
variants_counts_bed="$$_variants_with_counts.bed";
echo "$(date +'%b %d %H:%M:%S') - starting DB fetch"
./extract_all_variants.sh "$cutoff_date" > "$variants_bed";
echo "$(date +'%b %d %H:%M:%S') - DB fetch done"
shift 6;

for lineage_set_path in "$@"; do
  lineage_set_name=$(basename "$lineage_set_path" | sed -E "s/\.txt$//")
  echo "$(date +'%b %d %H:%M:%S') - processing lineage set $lineage_set_path"
  ./count_variants.sh "$variants_bed" "$min_pct" "$threads" "$lineage_set_path" > "$variants_counts_bed";
  xargs ./process_primer_sets.sh "$variants_counts_bed" "$output_path" "$score_cutoff" "$threads" "$lineage_set_name" < "$primer_sets_list_path";
done
echo "$(date +'%b %d %H:%M:%S') - script done"

rm "$$_variants.bed";