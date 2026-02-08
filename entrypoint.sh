#!/bin/bash
set -e

# Remove a potentially pre-existing server.pid for Rails
rm -f /app/tmp/pids/server.pid

# Wait for PostgreSQL to be ready
until pg_isready -h db -p 5432 -U postgres; do
  echo "Waiting for PostgreSQL to start..."
  sleep 2
done

# Install gems if missing (volume mount can overwrite bundled gems)
bundle check || bundle install

# Then exec the container's main process (what's set as CMD in the Dockerfile)
exec "$@"