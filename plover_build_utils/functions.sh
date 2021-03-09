#!/bin/bash

opt_dry_run=0
opt_timings=0

python='false'
wheels="$PWD/.cache/wheels"
downloads="$PWD/.cache/downloads"

# Usage: parse_opts args "$@"
#
# `$args` will be set to unhandled options and non-option arguments.
#
# Consumed options:
#
# --dry-run/-n: don't execute run/run_eval commands (print them instead)
# --debug/-d: enable `set -x` for debugging script
# --: stop options processing
#
# Tip: to update $@ after the call, use:
# parse_opts args "$@" && set -- "${args[@]}"
parse_opts()
{
  args_varname="$1"
  shift
  local _args=()
  while [ $# -ne 0 ]
  do
    case "$1" in
      --dry-run|-n)
        opt_dry_run=1
        ;;
      --debug|-d)
        set -x
        ;;
      --)
        shift
        _args+=("$@")
        break
        ;;
      *)
        _args+=("$1")
        ;;
    esac
    shift
  done
  eval "$args_varname=(${_args[@]@Q})"
}

info()
{
  color=34
  case "$1" in
    -c*)
      color="${1#-c}"
      shift
      ;;
  esac
  if [ -t 2 ]
  then
    echo "[${color}m$@[0m" 1>&2
  else
    echo "$@" 1>&2
  fi
}

err()
{
  info -c31 "$@"
}

die()
{
  code=$?
  if [ $# -ne 0 ]
  then
    code="$1"
    shift
  fi
  if [ $# -ne 0 ]
  then
    err "$@"
  fi
  exit "$code"
}

run()
{
  info "$@"
  [ $opt_dry_run -ne 0 ] && return
  if [ $opt_timings -ne 0 ]
  then
    time "$@"
  else
    "$@"
  fi
}

run_eval()
{
  info "$@"
  [ $opt_dry_run -ne 0 ] && return
  if [ $opt_timings -ne 0 ]
  then
    time eval "$@"
  else
    eval "$@"
  fi
}

get_base_devel()
{
  run "$python" -m plover_build_utils.get_pip -r requirements_base_devel.txt "$@"
}

install_wheels()
{
  run "$python" -m plover_build_utils.install_wheels --disable-pip-version-check "$@"
}

bootstrap_dist()
{
  wheel="$1"
  shift
  # We still need setuptools/wheel to be available (not even --use-pep517
  # works around that). While we're at it, install Plover's wheel too,
  # taking advantage of the fact that thanks to get_pip the current
  # working directory is not added to sys.path.
  get_base_devel "$wheel" --no-deps "$@" || die
  # Install the rest: Plover's dependencies, as well as standard plugins.
  install_wheels \
    -c requirements_base_devel.txt \
    -r requirements_distribution.txt \
    -r requirements_plugins.txt \
    "$@" || die
  # Avoid caching Plover's wheel.
  run rm "$wheels/$(basename "$wheel")"
}

parse_opts args "$@"
set -- "${args[@]}"
