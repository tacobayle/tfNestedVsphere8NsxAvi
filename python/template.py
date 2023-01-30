#!/usr/bin/env python3
from jinja2 import Template
import sys, json, yaml
json_file = open(sys.argv[2])
json_file.close
variables = json.load(json_file)
with open(sys.argv[1]) as file_:
    t = Template(file_.read())
output = t.render(variables)
with open(sys.argv[3], 'w') as f:
    f.write(output)