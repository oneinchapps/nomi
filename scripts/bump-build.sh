#!/bin/sh
# Erhöht die Build-Nummer (CURRENT_PROJECT_VERSION) in project.yml – vor jedem Upload nach App Store Connect.
# Mit Argument setzt es zusätzlich die Version: scripts/bump-build.sh 0.2.0
set -eu
cd "$(dirname "$0")/.."

build=$(sed -n 's/^    CURRENT_PROJECT_VERSION: "\([0-9]*\)"$/\1/p' project.yml)
[ -n "$build" ] || { echo "CURRENT_PROJECT_VERSION nicht gefunden" >&2; exit 1; }
next=$((build + 1))
sed -i '' "s/^    CURRENT_PROJECT_VERSION: \"$build\"$/    CURRENT_PROJECT_VERSION: \"$next\"/" project.yml

if [ $# -ge 1 ]; then
    sed -i '' "s/^    MARKETING_VERSION: \"[^\"]*\"$/    MARKETING_VERSION: \"$1\"/" project.yml
fi

xcodegen generate >/dev/null
version=$(sed -n 's/^    MARKETING_VERSION: "\(.*\)"$/\1/p' project.yml)
echo "Version $version, Build $next"
