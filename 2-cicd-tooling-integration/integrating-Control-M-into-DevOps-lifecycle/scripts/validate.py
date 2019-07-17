#! /usr/bin/env python

import sys
import csv
import json

sourcefile = sys.argv[1]

destfile = sys.argv[2]

input = csv.reader(open(sourcefile, 'r'))

sourcerows=0
for row in input:
    sourcerows += 1

fh = open(destfile, 'r')
outputsum=0
output = json.load(fh)
#print(output)
for i in output:
    outputsum += output[i]

if sourcerows == outputsum:
    exit(0)
else:
    print("Sum of values in transformed file doesn't match number of rows in source file!")
    exit(5)