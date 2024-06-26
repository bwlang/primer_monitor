"""
Filters duplicate sequences given previous day's file.
Usage: ./filter_duplicates.py <old data> <new data> > <output>
"""
import sys
import re


def get_strain(sequence_rec):
    """
    Converts a virus name into a strain ID.
    """
    regex = re.search('\"covv_virus_name\": \"(.*?)\",', sequence_rec)
    strain_name = regex.group(1)
    # do the same transformations ncov-ingest will do to ensure they don't create undetected dups
    strain_name = re.sub(r"\s", "", strain_name)
    strain_name = re.sub("^[nh]CoV-19/", "", strain_name)
    return strain_name


record_set = set([])
with open(sys.argv[1], "r") as old_records:
    for line in old_records:
        if line.strip() != "":  # skip blank lines
            strain = get_strain(line)
            record_set.add(strain)

with open(sys.argv[2], "r") as new_records:
    for line in new_records:
        line_stripped = line.strip()  # so line.strip() isn't called twice
        if line_stripped != "":  # skip blank lines
            strain = get_strain(line)
            if strain not in record_set:
                print(line_stripped)
                record_set.add(strain)  # do not output two of the same record, old or new
