
CREATE MATERIALIZED VIEW public.variant_overlaps AS
    SELECT oligos.id AS oligo_id,
          oligos.name AS oligo_name,
          oligo_alignment_positions.ref_start AS oligo_start,
          oligo_alignment_positions.ref_end AS oligo_end,
          oligo_alignment_positions.organism_taxon_id AS alignment_organism_taxon_id,
          oligos.short_name AS oligo_short_name,
          oligos.locus AS oligo_locus_name,
          oligos.category AS oligo_primer_type,
          primer_sets.id AS primer_set_id,
          primer_sets.name AS primer_set_name,
          variant_sites.id AS variant_id,
          variant_sites.variant_type,
          variant_sites.variant,
          variant_sites.ref_start AS variant_start,
          variant_sites.ref_end AS variant_end,
          COALESCE(detailed_geo_locations.region, ''::character varying) AS region,
          COALESCE(detailed_geo_locations.subregion, ''::character varying) AS subregion,
          COALESCE(detailed_geo_locations.division, ''::character varying) AS division,
          COALESCE(detailed_geo_locations.subdivision, ''::character varying) AS subdivision,
          detailed_geo_locations.id AS detailed_geo_location_id,
          COALESCE(fasta_records.date_collected, '1900-01-01'::date) AS date_collected
   FROM variant_sites
            JOIN fasta_records ON variant_sites.fasta_record_id = fasta_records.id
            JOIN detailed_geo_locations ON fasta_records.detailed_geo_location_id = detailed_geo_locations.id
            JOIN oligo_alignment_positions ON NOT (oligo_alignment_positions.ref_start >= variant_sites.ref_end OR oligo_alignment_positions.ref_end <= variant_sites.ref_start) AND fasta_records.organism_taxon_id = oligo_alignment_positions.organism_taxon_id
            JOIN oligos ON oligos.id = oligo_alignment_positions.oligo_id
            JOIN primer_sets ON oligos.primer_set_id = primer_sets.id
   WHERE variant_sites.usable_del_or_snp = true
   UNION ALL
   SELECT oligos.id AS oligo_id,
          oligos.name AS oligo_name,
          oligo_alignment_positions.ref_start AS oligo_start,
          oligo_alignment_positions.ref_end AS oligo_end,
          oligo_alignment_positions.organism_taxon_id AS alignment_organism_taxon_id,
          oligos.short_name AS oligo_short_name,
          oligos.locus AS oligo_locus_name,
          oligos.category AS oligo_primer_type,
          primer_sets.id AS primer_set_id,
          primer_sets.name AS primer_set_name,
          variant_sites.id AS variant_id,
          variant_sites.variant_type,
          variant_sites.variant,
          variant_sites.ref_start AS variant_start,
          variant_sites.ref_end AS variant_end,
          COALESCE(detailed_geo_locations.region, ''::character varying) AS region,
          COALESCE(detailed_geo_locations.subregion, ''::character varying) AS subregion,
          COALESCE(detailed_geo_locations.division, ''::character varying) AS division,
          COALESCE(detailed_geo_locations.subdivision, ''::character varying) AS subdivision,
          detailed_geo_locations.id AS detailed_geo_location_id,
          COALESCE(fasta_records.date_collected, '1900-01-01'::date) AS date_collected
   FROM variant_sites
            JOIN fasta_records ON variant_sites.fasta_record_id = fasta_records.id
            JOIN detailed_geo_locations ON fasta_records.detailed_geo_location_id = detailed_geo_locations.id
            JOIN oligo_alignment_positions ON NOT (oligo_alignment_positions.ref_start >= variant_sites.ref_end OR oligo_alignment_positions.ref_end <= variant_sites.ref_start) AND fasta_records.organism_taxon_id = oligo_alignment_positions.organism_taxon_id
            JOIN oligos ON oligos.id = oligo_alignment_positions.oligo_id
            JOIN primer_sets ON oligos.primer_set_id = primer_sets.id
   WHERE variant_sites.usable_insertion = true
WITH DATA;

-- View indexes:
CREATE INDEX variant_overlaps_region_subregion_division_subdivision_date_idx ON public.variant_overlaps USING btree (region, subregion, division, subdivision, date_collected);