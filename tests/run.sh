#!/bin/sh
# Needs qt6-qtdeclarative-devel and the Plasma QML modules (see .github/workflows/ci.yml)
set -e
cd "$(dirname "$0")/.."
QT_BIN=${QT_BIN:-/usr/lib64/qt6/bin}

"$QT_BIN/qmllint" --max-warnings 0 package/contents/ui/main.qml
# i18n() is only known at runtime in these files
"$QT_BIN/qmllint" --max-warnings 0 --unqualified disable \
    package/contents/ui/configGeneral.qml package/contents/config/config.qml

QT_QPA_PLATFORM=offscreen "$QT_BIN/qmltestrunner" -input tests
