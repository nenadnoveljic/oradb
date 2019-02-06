#!/usr/bin/python

# (c) 2019 Nenad Noveljic All Rights Reserved

# Usage: jppd_cbo_parser.py trace_file_name

# v1.1

# see https://nenadnoveljic.com/blog/suboptimal-execution-plan-with-join-predicate-push-down-transformation/

import sys
import re

def raise_error(message):
  print "ERROR: " + message
  sys.exit(1)

with open(sys.argv[1]) as f:
  content = f.readlines()

reg_checking = re.compile('JPPD:\s+Checking validity of push-down from query block (?P<qb_from>.+) to query block (?P<qb_to>.+)')
reg_discarded = re.compile('JPPD: Will not use JPPD from query block (?P<qb_from>.+)')
reg_done = re.compile('JPPD: Performing join predicate push-down \(final phase\) from query block (?P<qb_from>.+) to query block (?P<qb_to>.+)')
discarded = {}
used = {}

for line in content:
  line = line.rstrip("\n")

  matched_checking = reg_checking.match(line)
  if matched_checking:
    qb_checking_from = matched_checking.group('qb_from')
    qb_checking_to = matched_checking.group('qb_to')

  matched_discarded = reg_discarded.match(line)
  if matched_discarded:
    qb_from = matched_discarded.group('qb_from')
    if qb_from <> qb_checking_from:
      raise_error('Not matching QB ' + qb_checking_from + ' ' + qb_from)
    discarded[qb_from,qb_checking_to] = 1

  matched_done = reg_done.match(line)
  if matched_done:
    qb_done_from = matched_done.group('qb_from')
    qb_done_to = matched_done.group('qb_to')
    used[qb_done_from,qb_done_to] = 1

print "JPPDs that shouldn't haved occured:"
for used_qb_from,used_qb_to in used:
  if (used_qb_from,used_qb_to) in discarded.keys():
    print used_qb_from + ' => ' + used_qb_to

f.close()
