#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./install-openclaw-plugin-from-source.sh [options]

Build and link this local MLflow OpenClaw plugin checkout into OpenClaw, then
restart the OpenClaw gateway.

Options:
  --copy          Copy the plugin into OpenClaw instead of linking it
  --skip-install  Do not install npm dependencies before building
  --skip-build    Do not run npm build before installing
  --skip-restart  Do not restart the OpenClaw gateway after installing
  -h, --help      Show this help message
EOF
}

install_mode="--link"
install_deps=1
run_build=1
restart_gateway=1

while [ "$#" -gt 0 ]; do
  case "$1" in
    --copy)
      install_mode=""
      ;;
    --skip-install)
      install_deps=0
      ;;
    --skip-build)
      run_build=0
      ;;
    --skip-restart)
      restart_gateway=0
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
typescript_dir="$repo_root/libs/typescript"
plugin_dir="$repo_root/libs/typescript/integrations/openclaw"

if [ ! -f "$plugin_dir/package.json" ] || [ ! -f "$plugin_dir/openclaw.plugin.json" ]; then
  echo "Could not find OpenClaw plugin files in $plugin_dir" >&2
  exit 1
fi

if ! command -v openclaw >/dev/null 2>&1; then
  echo "openclaw is not installed or is not on PATH" >&2
  exit 1
fi

if [ "$run_build" -eq 1 ]; then
  if ! command -v npm >/dev/null 2>&1; then
    echo "npm is required to build the plugin. Re-run with --skip-build to skip this step." >&2
    exit 1
  fi

  if [ "$install_deps" -eq 1 ] && [ ! -x "$typescript_dir/node_modules/.bin/tsc" ]; then
    echo "Installing TypeScript workspace dependencies from $typescript_dir"
    npm install -C "$typescript_dir"
  fi

  echo "Building OpenClaw plugin from $plugin_dir"
  npm run -C "$plugin_dir" build
fi

if [ -n "$install_mode" ]; then
  echo "Linking OpenClaw plugin from $plugin_dir"
  openclaw plugins install "$install_mode" "$plugin_dir"
else
  echo "Installing OpenClaw plugin from $plugin_dir"
  openclaw plugins install "$plugin_dir"
fi

if [ "$restart_gateway" -eq 1 ]; then
  echo "Restarting OpenClaw gateway"
  openclaw gateway restart
fi
