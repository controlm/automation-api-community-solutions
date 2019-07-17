#! /usr/bin/env python3

import sys
import csv
import json

filename = sys.argv[1]

input = csv.reader(open(filename, 'r'))

result = {}
for row in input:
    state = row[4]
    if state in result:
        result[state] += 1
    else:
        result[state] = 1


output = open('results.json', 'w')
json.dump(result, output)