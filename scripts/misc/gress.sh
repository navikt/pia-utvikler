#!/bin/bash

env=$1
reason=$2
command='No valid environment received (dev|prod)'
execute=false

if [ -z "$reason" ]; then
  echo "Please provide reason as the second argument"
  exit 1
fi

if [[ $env = 'dev' ]]; then
  command="nais cloudsql proxy lydia-api --environment dev-gcp --port 5433 --reason '$reason'"
  execute=true
elif [[ $env = 'prod' ]]; then
  command="nais cloudsql proxy lydia-api --environment prod-gcp --port 5431 --reason '$reason'"
  echo "Are you sure you wish to connect to prod db? (y/N)"
  read answer
  if [[ $answer = 'y' ]]; then
    execute=true
  fi
fi

echo "$command"

if $execute; then
  eval "$command"
fi

