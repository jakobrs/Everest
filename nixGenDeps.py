#! /usr/bin/env nix-shell
#! nix-shell -i python3 -p python3

# WARNING: This script *will* overwrite any file called deps.json in the
# working directory

from xml.dom import minidom
import json
import subprocess

config = minidom.parse('Celeste.Mod.mm/packages.config')
deps = config.getElementsByTagName('package')

out = []

for dep in deps:
  depId, depVersion, depFramework = dep.attributes['id'].value, dep.attributes['version'].value, dep.attributes['targetFramework'].value

  depHashProc = subprocess.Popen(
    [
      'nix-prefetch-url',
      'https://www.nuget.org/api/v2/package/{:s}/{:s}'.format(depId, depVersion),
    ],
    stdout = subprocess.PIPE,
    encoding = 'UTF-8',
  )

  out.append({
    'name':      depId,
    'version':   depVersion,
    'framework': depFramework,
    'sha256':    depHashProc,
  }) 

for dep in out:
  depHashProc = dep['sha256']
  outs = depHashProc.communicate()
  dep['sha256'] = outs[0][:-1]

with open('deps.json', 'w') as outfile:
  json.dump(out, outfile, indent=2)
