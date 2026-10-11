param([string]$BaseHref = '/')
$ErrorActionPreference = 'Stop'
flutter build web --release --no-web-resources-cdn --pwa-strategy=none --base-href $BaseHref
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
dart run tool/generate_offline.dart
exit $LASTEXITCODE
