#!/usr/bin/env python

import yaml, argparse

parser = argparse.ArgumentParser()
parser.add_argument("infile", help="the playbook to reverse convert")
parser.add_argument("outfile", help="filename for reversed playbook")
parser.add_argument("-v","--verbose", help="print new yaml file", action="store_true")
args = parser.parse_args()

try:
  playbook = yaml.load(file(args.infile, 'r'))
  if len(playbook) == 1 and playbook[0]['tasks'] is not None:
    tasks = playbook[0]['tasks']
    tasks.reverse()
    for task in tasks:
      for key in task:
        if 'state' in task[key]:
          task[key]['state'] = 'absent'
    playbook[0]['tasks'] = tasks
    if args.verbose:
        print yaml.dump(playbook, default_flow_style=False)
    rev_file = file(args.outfile, 'w')
    print "saving reversed version of {} to {}".format(args.infile, args.outfile)
    yaml.dump(playbook, rev_file, default_flow_style=False)
except yaml.YAMLError:
  print "not a valid playbook"
