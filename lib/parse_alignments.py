#!/usr/bin/python3

import sys
import re

def parse_cigar(cigar_string):
    parsed = re.findall("(\d+[\w=])", cigar_string)
    return parsed

print("Strain\tReference position\tVariant type\tVariant")
for line in sys.stdin:
    line = line.strip().split("\t")
    query_name = line[0]
    ref_start = int(line[3])
    cigar = line[5]
    query_seq = line[9]
    parsed_cigar = parse_cigar(cigar)

    # print(parsed_cigar)
    query_start = 0
    for item in parsed_cigar:
        length = int(item[:-1])
        type = item[len(item)-1:]

        if type != "=":
            print("{}\t{}\t{}\t{}".format(query_name, ref_start, type, query_seq[query_start : query_start + length]))

        query_start += length
        ref_start += length
        