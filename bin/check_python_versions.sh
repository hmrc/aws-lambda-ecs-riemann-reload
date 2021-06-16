#!/usr/bin/env bash

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
asdf_version_file="$root_dir/.tool-versions"
pyenv_version_file="$root_dir/.python-version"

if diff <(cat "$asdf_version_file" | grep python | awk '{print $2}') <(cat "$pyenv_version_file"); then
  echo "Python version files are in sync"
  exit 0
else
  echo "Python version divergence detected between ${asdf_version_file} and ${pyenv_version_file}"
  exit 1
fi
