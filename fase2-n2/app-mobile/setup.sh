#!/usr/bin/env bash
# Prepara o projeto Android (roda uma unica vez, dentro de app-mobile/)
set -e
command -v flutter >/dev/null || { echo "Instale o Flutter: https://docs.flutter.dev/get-started/install"; exit 1; }

# guarda os arquivos do projeto, pois o 'flutter create' pode sobrescrever
TMP=$(mktemp -d)
cp pubspec.yaml "$TMP/"; cp -r lib "$TMP/lib"; cp -r test "$TMP/test"

flutter create --org br.projeto --project-name monitor_iot --platforms android .

cp "$TMP/pubspec.yaml" pubspec.yaml
rm -rf lib test && cp -r "$TMP/lib" lib && cp -r "$TMP/test" test

# permissao de internet no manifest principal (necessaria no APK release)
MANIFEST=android/app/src/main/AndroidManifest.xml
grep -q "android.permission.INTERNET" "$MANIFEST" || \
  sed -i '0,/<application/s//<uses-permission android:name="android.permission.INTERNET"\/>\n    <application/' "$MANIFEST"

flutter pub get
echo "Pronto. Copie env.example.json para env.json, preencha o token e rode:"
echo "  flutter run --dart-define-from-file=env.json"
