#!/usr/bin/env bash

set -e

variants_counts_bed="$1";
primer_bed="$2";
output_file="$3";
score_cutoff="$4";
threads="$5";

"$(dirname "$0")/classify_overlaps.sh" "$variants_counts_bed" "$primer_bed" "$score_cutoff" "$threads" "$$_intersects.bed" "$$_no_intersects.bed";

awk 'BEGIN{ OFS="\t" }; { print $1, $2, $3, $4, $5, $6, $2, $2, "0,0,200" }' < $$_no_intersects.bed > $$_no_intersects_color.bed;
awk 'BEGIN{ OFS="\t" }; { print $1, $2, $3, $4, $5, $6, $2, $2, "230,100,0" }' < $$_intersects.bed > $$_intersects_color.bed;

sort -k1 -k2n $$_no_intersects_color.bed $$_intersects_color.bed > "$output_file";

rm $$_no_intersects.bed $$_intersects.bed $$_no_intersects_color.bed $$_intersects_color.bed;
