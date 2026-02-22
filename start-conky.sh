#!/bin/bash
set -euo pipefail

killall conky --quiet || true
conky --quiet --daemonize
