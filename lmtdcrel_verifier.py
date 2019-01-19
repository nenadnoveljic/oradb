#!/usr/bin/python

#(c) 2019 Nenad Noveljic All Rights Reserved

# Usage: lmtdcrel_verifier.py lmtdcrel.log

# see 

# v1.0

import sys
import re

def raise_error(line_num, line, message):
  print "ERROR: " + message
  print "line number: " + str(line_num) 
  i = 0
  while i < len(line_arr):
    print line_arr[i]
    i += 1
  exit(1)

with open(sys.argv[1]) as f:
  content = f.readlines()

reg_return_code = re.compile('.*= (-?\d+)$')
reg_xmm = re.compile('.*=.*v2_double = {(\S+),.*')

xmm = [None] * 2
line_arr = [None] * 3

line_num=1
for line in content:
  line = line.rstrip("\n")
  value_type = line_num % 3
  line_arr[value_type-1] = line

  if value_type == 0:
    matched_return_code = reg_return_code.match(line)
    if matched_return_code:
      return_code = int(matched_return_code.group(1))
    else:
      raise_error(line_num, line, "Can't parse line")

    if xmm[0] > xmm[1]:
      calculated_return_code = 1
    elif xmm[0] == xmm[1]:
      calculated_return_code = 0
    else:
      calculated_return_code = -1
    
    if calculated_return_code != return_code:
      raise_error(line_num, line_arr, "Wrong return code (xmm0=" + str(xmm[0]) + " xmm1=" + str(xmm[1]) + " return code=" + str(return_code)
 + " calculated: " + str(calculated_return_code) + ")" );

  elif value_type == 1 or value_type == 2 :  
    matched_xmm = reg_xmm.match(line)
    if matched_xmm:
      xmm[value_type-1] = '{:0.7e}'.format(float(matched_xmm.group(1)))
    else:
      raise_error(line_num, line, "Can't parse line")
  else:
      raise_error(line_num, line, "Wrong value_type" + value_type)

  line_num += 1

print "OK: No discrepancies found"
