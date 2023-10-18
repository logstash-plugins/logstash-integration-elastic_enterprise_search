#!/usr/bin/env bash

# This is intended to be run inside the docker container as the command of the docker-compose.
set -ex

export USER='logstash'

source .ci/retrieve_app_search_credentials.sh

if [[ "$SECURE_INTEGRATION" == "true" ]]; then
  extra_tag_args=" --tag secure_integration:true"
else
  extra_tag_args="--tag ~secure_integration:true"
fi

bundle exec rspec --format=documentation spec/unit --tag ~integration:true --tag ~secure_integration:true && bundle exec rspec --format=documentation --tag integration $extra_tag_args spec/integration