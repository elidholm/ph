#!/usr/bin/env bash
#
# ph - Command line interface for the Pi-hole API.
#
# Author:      Edvin Lidholm
# Maintainer:  Edvin Lidholm
# Repository:  https://github.com/elidholm/ph
# License:     Apache License 2.0 (see LICENSE)
#
# Description:
#   Small CLI wrapper around the Pi-hole REST API. Currently supports
#   temporarily disabling Pi-hole blocking for a specified duration.
#

# color codes
NC='\033[0m'
RED='\033[00;31m'
GREEN='\033[00;32m'
PURPLE='\033[00;35m'
BLUE='\033[00;34m'
SEA='\033[38;5;49m'
YELLOW='\033[00;33m'

VERBOSE=${VERBOSE:-false}
QUIET=${QUIET:-false}

pihole_api_url=${PIHOLE_API_URL-}
default_duration=10
curl_timeout=15

print_usage() {
  cat <<EOF

Usage: ${0##*/} [command] [arguments]

Command line interface for the Pi-hole API.

Commands:
  disable           Disable Pi-hole for a specified duration (default: ${default_duration} seconds)
  enable            Enable Pi-hole for a specified duration (default: ${default_duration} seconds)
  status            Show the current Pi-hole blocking status

Arguments:
  -h, --help        Show this help message
EOF
}

common_usage_args() {
  cat <<EOF
  -h, --help        Show this help message
  -v, --verbose     Enable verbose logging
  --no-color        Disable color output
  -q, --quiet       Suppress all logging output (overrides verbose)
EOF
}

print_disable_usage() {
  cat <<EOF

Usage: ${0##*/} disable [arguments]

Disable Pi-hole blocking for a duration, then orignial blocking state resumes automatically.

Arguments:
  -<n>              Duration in seconds to disable Pi-hole (default: ${default_duration})
$(common_usage_args)

Examples:
  ${0##*/} disable
  ${0##*/} disable -30
EOF
}

print_enable_usage() {
  cat <<EOF

Usage: ${0##*/} enable [arguments]

Enable Pi-hole blocking for a duration, then original blocking state resumes automatically.

Arguments:
  -<n>              Duration in seconds to enable Pi-hole (default: ${default_duration})
$(common_usage_args)

Examples:
  ${0##*/} enable
  ${0##*/} enable -30
EOF
}

print_status_usage() {
  cat <<EOF

Usage: ${0##*/} status [arguments]

Show the current Pi-hole blocking status.

Arguments:
$(common_usage_args)
EOF
}

info() {
  if [[ ${QUIET-} == true ]]; then
    return 0
  fi
  local msg=$*
  local timestamp

  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  printf "${PURPLE}%s\t${BLUE}   [INFO]${NC}\t%s\n" "$timestamp" "$msg"
}

debug() {
  if [[ ${QUIET-} == true || ${VERBOSE-} == false ]]; then
    return 0
  fi
  local msg=$*
  local timestamp

  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  printf "${PURPLE}%s\t${SEA}  [DEBUG]${NC}\t%s\n" "$timestamp" "$msg"
}

warning() {
  if [[ ${QUIET-} == true ]]; then
    return 0
  fi
  local msg=$*
  local timestamp

  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  printf "${PURPLE}%s\t${YELLOW}[WARNING]${NC}\t%s\n" "$timestamp" "$msg" >&2
}

fatal() {
  if [[ ${QUIET-} == true ]]; then
    return 0
  fi
  local msg=$*
  local timestamp

  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  printf "${PURPLE}%s\t${RED}  [FATAL]${NC}\t%s\n" "$timestamp" "$msg" >&2
  return 1
}

usage_error() {
  local usage_printer=$1
  shift

  local msg=$*

  printf "${RED}[ERROR]${NC} %s\n" "$@"
  "$usage_printer" >&2
  return 1
}

verify_dependencies() {
  local dependency
  local dependencies=(curl jq)

  debug "Verifying required dependencies: ${dependencies[*]}"
  for dependency in "${dependencies[@]}"; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
      fatal "Missing dependency: $dependency"
      return 1
    fi
    debug "Found dependency: $dependency"
  done
}

validate_duration() {
  local duration=$1

  debug "Validating duration: $duration"
  [[ $duration =~ ^[0-9]+$ ]] && ((duration > 0))
}

get_session_id() {
  local auth_payload
  local auth_response
  local session_id

  debug 'Requesting Pi-hole authentication token...' >&2
  auth_payload=$(jq -n --arg password "$PIHOLE_API_KEY" '{password: $password}') || {
    fatal 'Failed to build the authentication request.'
    return 1
  }

  if ! auth_response=$(curl --silent --show-error --fail-with-body \
    --connect-timeout "$curl_timeout" --max-time "$curl_timeout" \
    --header 'Content-Type: application/json' \
    --data "$auth_payload" \
    "${pihole_api_url}/auth"); then
    fatal 'Pi-hole authentication request failed.'
    return 1
  fi
  debug 'Received Pi-hole authentication response.' >&2

  if ! session_id=$(jq --exit-status --raw-output '.session.sid // empty' <<<"$auth_response"); then
    fatal 'Pi-hole authentication response did not contain a session ID.'
    return 1
  fi
  info 'Authenticated with Pi-hole successfully.' >&2

  printf '%s\n' "$session_id"
}

disable_blocking() {
  local duration=$1
  local session_id=$2
  local response

  info "Disabling Pi-Hole for $duration seconds..."
  debug "Sending disable request to Pi-hole API (timer=${duration})..."

  if ! response=$(curl --silent --show-error --fail-with-body \
    --connect-timeout "$curl_timeout" --max-time "$curl_timeout" \
    --header 'Content-Type: application/json' \
    --header "X-FTL-SID: ${session_id}" \
    --data "{\"blocking\":false,\"timer\":${duration}}" \
    "${pihole_api_url}/dns/blocking"); then
    fatal 'Pi-hole blocking request failed.'
    return 1
  fi

  debug "Pi-hole response: $response"
  printf "${GREEN}%s${NC}\n" '[SUCCESS]: Pi-hole blocking has been disabled.'
}

enable_blocking() {
  local duration=$1
  local session_id=$2
  local response

  info "Enabling Pi-Hole for $duration seconds..."
  debug "Sending enable request to Pi-hole API (timer=${duration})..."

  if ! response=$(curl --silent --show-error --fail-with-body \
    --connect-timeout "$curl_timeout" --max-time "$curl_timeout" \
    --header 'Content-Type: application/json' \
    --header "X-FTL-SID: ${session_id}" \
    --data "{\"blocking\":true,\"timer\":${duration}}" \
    "${pihole_api_url}/dns/blocking"); then
    fatal 'Pi-hole blocking request failed.'
    return 1
  fi

  debug "Pi-hole response: $response"
  printf "${GREEN}%s${NC}\n" '[SUCCESS]: Pi-hole blocking has been enabled.'
}

blocking_status() {
  local session_id=$1
  local response

  info 'Retrieving Pi-Hole blocking status...'
  debug 'Sending status query request to Pi-hole API...'

  if ! response=$(curl --silent --show-error --fail-with-body \
    --connect-timeout "$curl_timeout" --max-time "$curl_timeout" \
    --header 'Content-Type: application/json' \
    --header "X-FTL-SID: ${session_id}" \
    "${pihole_api_url}/dns/blocking"); then
    fatal 'Pi-hole blocking request failed.'
    return 1
  fi

  debug "Pi-hole response: $response"
  blocking_enabled=$(jq --exit-status --raw-output '.blocking // empty' <<<"$response")
  timer=$(jq --exit-status --raw-output '.timer // empty' <<<"$response")
  response_time=$(jq --exit-status --raw-output '.took // empty' <<<"$response")

  printf "${GREEN}%s${NC}\n" 'Pi-hole blocking status:'
  printf "\t${BLUE}%s${YELLOW}%s${NC} " 'Blocking' ':'
  if [[ $blocking_enabled == enabled ]]; then
    printf "${GREEN}%s${NC}\n" 'Enabled'
  else
    printf "${RED}%s${NC}\n" 'Disabled'
  fi
  printf "\t${BLUE}%s${YELLOW}%s${NC} %s\n" 'Timer' ':' "${timer:-N/A}"
  printf "\t${BLUE}%s${YELLOW}%s${NC} %s\n" 'Response time' ':' "${response_time}s"
}

close_session() {
  local session_id=$1

  debug 'Closing Pi-hole session...'
  if ! curl --silent --show-error --fail-with-body --request DELETE \
    --connect-timeout "$curl_timeout" --max-time "$curl_timeout" \
    --header "X-FTL-SID: ${session_id}" \
    "${pihole_api_url}/auth" >/dev/null; then
    warning 'Failed to close Pi-hole session (best-effort, ignoring).'
  fi
  debug 'Pi-hole session closed.'
}

require_environment() {
  verify_dependencies || return 1
  if [[ -z ${PIHOLE_API_URL-} ]]; then
    fatal 'Environment variable PIHOLE_API_URL is required.'
    return 1
  fi
  debug 'PIHOLE_API_URL is set.'
  if [[ -z ${PIHOLE_API_KEY-} ]]; then
    fatal 'Environment variable PIHOLE_API_KEY is required.'
    return 1
  fi
  debug 'PIHOLE_API_KEY is set.'
}

with_pihole_session() {
  local work_fn=$1
  shift
  local session_id
  local exit_status

  session_id=$(get_session_id) || return 1
  "$work_fn" "$@" "$session_id"
  exit_status=$?
  close_session "$session_id"
  return "$exit_status"
}

disable_command() {
  local argument
  local duration=''
  local session_id

  for argument in "$@"; do
    debug "Parsing argument: $argument"
    case $argument in
    help | -h | --help)
      print_disable_usage
      return 0
      ;;
    -[0-9]*)
      if [[ -n $duration ]]; then
        usage_error print_disable_usage 'disable accepts at most one duration.'
        return 1
      fi
      duration=${argument#-}
      if ! validate_duration "$duration"; then
        usage_error print_disable_usage "Duration must be a positive integer: ${argument@Q}"
        return 1
      fi
      ;;
    -v | --verbose)
      VERBOSE=true
      debug 'Verbose logging enabled.'
      ;;
    --no-color)
      debug 'Disabling color output.'
      RED=$NC
      GREEN=$NC
      PURPLE=$NC
      BLUE=$NC
      SEA=$NC
      YELLOW=$NC
      ;;
    -q | --quiet)
      QUIET=true
      ;;
    *)
      usage_error print_disable_usage "Unknown argument: ${argument@Q}"
      return 1
      ;;
    esac
  done

  duration=${duration:-$default_duration}
  debug "Resolved duration: ${duration}s"

  require_environment || return 1
  with_pihole_session disable_blocking "$duration"
}

enable_command() {
  local argument
  local duration=''
  local session_id

  for argument in "$@"; do
    debug "Parsing argument: $argument"
    case $argument in
    help | -h | --help)
      print_enable_usage
      return 0
      ;;
    -[0-9]*)
      if [[ -n $duration ]]; then
        usage_error print_enable_usage 'enable accepts at most one duration.'
        return 1
      fi
      duration=${argument#-}
      if ! validate_duration "$duration"; then
        usage_error print_enable_usage "Duration must be a positive integer: ${argument@Q}"
        return 1
      fi
      ;;
    -v | --verbose)
      VERBOSE=true
      debug 'Verbose logging enabled.'
      ;;
    --no-color)
      debug 'Disabling color output.'
      RED=$NC
      GREEN=$NC
      PURPLE=$NC
      BLUE=$NC
      SEA=$NC
      YELLOW=$NC
      ;;
    -q | --quiet)
      QUIET=true
      ;;
    *)
      usage_error print_enable_usage "Unknown argument: ${argument@Q}"
      return 1
      ;;
    esac
  done

  duration=${duration:-$default_duration}
  debug "Resolved duration: ${duration}s"

  require_environment || return 1
  with_pihole_session enable_blocking "$duration"
}

status_command() {
  local argument
  local session_id

  for argument in "$@"; do
    debug "Parsing argument: $argument"
    case $argument in
    help | -h | --help)
      print_status_usage
      return 0
      ;;
    -v | --verbose)
      VERBOSE=true
      debug 'Verbose logging enabled.'
      ;;
    --no-color)
      debug 'Disabling color output.'
      RED=$NC
      GREEN=$NC
      PURPLE=$NC
      BLUE=$NC
      SEA=$NC
      YELLOW=$NC
      ;;
    -q | --quiet)
      QUIET=true
      ;;
    *)
      usage_error print_status_usage "Unknown argument: ${argument@Q}"
      return 1
      ;;
    esac
  done

  require_environment || return 1
  with_pihole_session blocking_status
}

main() {
  local command=${1-}

  debug "Dispatching command: ${command:-<none>}"
  case $command in
  -h | --help)
    print_usage
    ;;
  disable)
    shift
    disable_command "$@"
    ;;
  enable)
    shift
    enable_command "$@"
    ;;
  status)
    shift
    status_command "$@"
    ;;
  '')
    print_usage >&2
    return 1
    ;;
  *)
    usage_error print_usage "Unknown command: ${command@Q}"
    ;;
  esac
}

main "$@"
