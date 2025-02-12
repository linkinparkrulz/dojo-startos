#!/bin/bash
# vim: sw=2 ts=2 sts=2 et ai

do_authenticate () {
  local ak=$1
  auth_result=$(curl -X POST -s --data-binary "apikey=$ak&at=null" -H "Content-Type: application/json" "http://localhost:8080/auth/login")
  at=$(echo "$auth_result" | yq e ".authorizations.access_token" 2>/dev/null)
  if [ -n "$at" ] && [ "$at" != "null" ]; then
    echo "$at" > /run/secrets/access_token
    echo "$at"
  else
    return 1
   fi
}

get_pushtx_status () {
  local access_token=$1
  status=$(curl -s -H "Content-Type: application/json" "http://localhost:8081/status?at=$access_token")
  maybe_error=$(echo "$status" | yq -e '.error' 2>/dev/null)
  if [ "$maybe_error" == 'Invalid JSON Web Token' ]; then
    return 1
  else
    echo "$status"
  fi
}

get_account_status () {
  local access_token=$1
  status=$(curl -s -H "Content-Type: application/json" "http://localhost:8080/status?at=$access_token")
  maybe_error=$(echo "$status" | yq -e '.error' 2>/dev/null)
  if [ "$maybe_error" == 'Invalid JSON Web Token' ]; then
    return 1
  else
    echo "$status"
  fi
}

check_token () {
  local access_token=$1
  status=$(curl -s -H "Content-Type: application/json" "http://localhost:8080/status?at=$access_token")
  maybe_error=$(echo "$status" | yq -e '.error' 2>/dev/null)
  if [ "$maybe_error" == 'Invalid JSON Web Token' ]; then
    return 1
  else
    return 0
  fi
}
