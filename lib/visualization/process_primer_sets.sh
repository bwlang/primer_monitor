#!/usr/bin/env bash

variants_counts_bed="$1";
output_path="$2";
score_cutoff="$3";
threads="$4";
name="$5";

shift 5;

for primer_bed in "$@"; do
	outputname=$(basename "$primer_bed" | sed -E "s/\.bed$//I");
	mkdir -p "$output_path/${outputname}";
	./primers_affected.sh "$variants_counts_bed" "$primer_bed" "$output_path/${outputname}/$name.bed" "$score_cutoff" "$threads" ;
done

rm "$variants_counts_bed";