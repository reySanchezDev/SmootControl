$ErrorActionPreference = 'Stop'

flutter clean
flutter pub get
dart compile js -O2 -o web\drift_worker.js web\drift_worker.dart
flutter build web --release --no-wasm-dry-run --no-web-resources-cdn --pwa-strategy=none

Copy-Item web\sqlite3.wasm build\web\sqlite3.wasm -Force
Copy-Item web\drift_worker.js build\web\drift_worker.js -Force

Write-Host 'Build Web release listo con assets Drift copiados.'
