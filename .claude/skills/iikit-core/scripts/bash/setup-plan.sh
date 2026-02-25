#!/usr/bin/env bash
# DEPRECATED: Use check-prerequisites.sh --phase 02
exec bash "$(dirname "$0")/check-prerequisites.sh" --phase 02 "$@"
