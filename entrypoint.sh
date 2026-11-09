#!/bin/bash
set -e

# Generate datacube.conf from template with environment variables
if [ -f /home/odc/.datacube.conf.template ]; then
    envsubst < /home/odc/.datacube.conf.template > /home/odc/.datacube.conf
    echo "Generated datacube.conf from environment variables"
fi

exec "$@"
