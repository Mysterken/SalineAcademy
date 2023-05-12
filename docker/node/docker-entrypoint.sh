#!/bin/sh

set -e

# Check if the node_modules directory is present
if [ ! -d "node_modules" ]; then
  # Install dependencies with Yarn
  yarn install --frozen-lockfile
fi

exec "$@"
