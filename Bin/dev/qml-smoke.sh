#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if ! command -v qmlscene >/dev/null 2>&1; then
  echo "qmlscene not found; skipping QML smoke test (install Qt6 declarative tools to enable)." >&2
  exit 0
fi

HARNESS="$(mktemp)"
trap 'rm -f "$HARNESS"' EXIT

cat > "$HARNESS" <<'EOF'
import QtQuick
import Quickshell
import qs.Commons
import qs.Services.System
import qs.Services.Location
import qs.Services.Networking

Item {
  Component.onCompleted: {
    // Touch key singletons to catch missing imports early
    const _s = Settings.settingsVersion;
    const _loc = LocationService.coordinatesReady;
    const _net = NetworkService.scanPending;
    const _prog = ProgramCheckerService.taskwarriorAvailable;
    Qt.quit();
  }
}
EOF

QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}" \
QML2_IMPORT_PATH="${ROOT}:${QML2_IMPORT_PATH:-}" \
qmlscene -I "$ROOT" "$HARNESS" --quit >/dev/null

echo "QML smoke test passed (imports resolved)."
