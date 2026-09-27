#!/bin/bash
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
model="$(/usr/sbin/sysctl -n hw.model)"
[[ "$model" == VirtualMac* ]] || { echo 'Use a disposable macOS VM.' >&2; exit 1; }
(( EUID == 0 )) || { echo 'Run as root inside the VM.' >&2; exit 1; }
state="$(/usr/sbin/ioreg -r -c IOPMrootDomain -d 1 -l | /usr/bin/awk -F'= ' '/"SleepDisabled"/ { print $2; exit }')"
[[ "$state" == No ]] || { echo 'Normal sleep must be enabled before testing.' >&2; exit 1; }

test_dir="$(/usr/bin/mktemp -d /tmp/lid-awake-helper-test.XXXXXX)"
binary="$test_dir/helper-test"
marker='/Library/Application Support/LidAwake/com.kzahel.lidawake.helper.integration.session'
cleanup() {
  /usr/bin/pmset -a disablesleep 0
  /bin/rm -f "$marker" "$binary"
  /bin/rmdir "$test_dir"
}
trap cleanup EXIT

/usr/bin/swiftc -O \
  "$repo_dir/Sources/Shared/PowerState.swift" \
  "$repo_dir/Sources/Shared/SessionPolicy.swift" \
  "$repo_dir/Sources/Shared/HelperProtocol.swift" \
  "$repo_dir/Sources/Helper/PowerController.swift" \
  "$repo_dir/Sources/Helper/HelperService.swift" \
  "$repo_dir/Tests/HelperIntegration/main.swift" \
  -o "$binary"

"$binary" exercise
"$binary" recover
"$binary" watchdog
"$binary" retry
