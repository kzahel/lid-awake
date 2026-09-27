#!/bin/bash
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
model="$(/usr/sbin/sysctl -n hw.model)"
[[ "$model" == VirtualMac* ]] || { echo 'Use a disposable macOS VM.' >&2; exit 1; }
label='com.kzahel.lidawake.helper'
/bin/launchctl print "system/$label" >/dev/null

test_dir="$(/usr/bin/mktemp -d /tmp/lid-awake-xpc-test.XXXXXX)"
trap '/bin/rm -rf "$test_dir"' EXIT
/usr/bin/swiftc "$repo_dir/Tests/XPCUnauthorized/main.swift" -o "$test_dir/unauthorized-probe"
start="$(/bin/date '+%Y-%m-%d %H:%M:%S')"
"$test_dir/unauthorized-probe" "$label"
/bin/sleep 2
/usr/bin/log show --start "$start" --style compact --predicate 'process == "LidAwakeHelper"' 2>/dev/null |
  /usr/bin/grep -F 'Received message forbidden due to code signing requirement' >/dev/null || {
    echo 'The helper log did not confirm a code-signing rejection.' >&2
    exit 1
  }
echo 'Helper log confirmed that the unsigned XPC message was forbidden by its signing requirement.'
