#!/usr/bin/env bash
# Recria as pastas de plataforma (android/web) se forem apagadas. Roda dentro de app-mobile/.
set -e
command -v flutter >/dev/null || { echo "Instale o Flutter: https://docs.flutter.dev/get-started/install"; exit 1; }
TMP=$(mktemp -d)
cp pubspec.yaml "$TMP/"; cp -r lib "$TMP/lib"; cp -r test "$TMP/test"
flutter create --org br.com.pulsobiz --project-name monitor_iot --platforms android,web .
cp "$TMP/pubspec.yaml" pubspec.yaml
rm -rf lib test && cp -r "$TMP/lib" lib && cp -r "$TMP/test" test
rm -f README.md monitor_iot.iml
M=android/app/src/main/AndroidManifest.xml
grep -q "android.permission.INTERNET" "$M" || sed -i '0,/<application/s//<uses-permission android:name="android.permission.INTERNET"\/>\n    <application/' "$M"
sed -i 's#android:label="[^"]*"#android:label="PulsoBiz"#' "$M"
flutter pub get
dart run flutter_launcher_icons
echo "Pronto. Rode: flutter run   |   flutter build apk --release"
