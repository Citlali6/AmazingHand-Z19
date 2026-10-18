#!/bin/sh
# Manual SysV-Linux service entry; lives entirely in /run. No boot installation.
set -eu
cd "$(dirname "$0")"
exec python3 ./linux_hil.py "$@"
