# TO-DO-IN Indonesia (`todoin.id`) — Agent Guidelines & Project Memory

Dokumen ini adalah salinan panduan workspace context untuk seluruh AI agents yang bekerja pada repositori ini. Rincian selengkapnya dapat dilihat di [GEMINI.md](file:///Users/asyiraaf/Documents/Ngoding/to-do-in/GEMINI.md) dan [PROJECT_MEMORY.md](file:///Users/asyiraaf/Documents/Ngoding/to-do-in/docs/PROJECT_MEMORY.md).

## Quick Context:
1. **Backend:** PocketBase v0.25+ di VPS Contabo: `https://pb-dev.todoin.id`.
2. **Flutter Version:** `3.24.5` (Dart `3.5.4`). Kunci versi ini pada semua script CI/CD.
3. **Navpill Design:** Floating pill capsule dengan 44px circular Action Button (+) tanpa teks label di bawahnya.
4. **iOS Build (CI/CD):** Gunakan `runs-on: macos-latest`, `flutter-version: '3.24.5'`, `zip -r -y -q todoin-release.ipa Payload`.
5. **Android Build:** AGP `8.5.2`, Kotlin `2.1.0`, Gradle `8.9-all`, Java 17.
