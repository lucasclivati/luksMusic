#!/bin/sh
# Builds the Steam Deck package inside a Linux container (jpackage only builds Linux app images on Linux).
# From the repository root on any machine with Docker:
#   docker run --rm -v "$PWD":/src -v luksmusic-gradle:/root/.gradle eclipse-temurin:21-jdk sh /src/android/desktop/packaging/build-linux.sh
# The archive lands in android/desktop/build/dist/luksMusic-linux-x64.tar.gz.
set -e
apt-get update -qq >/dev/null && apt-get install -y -qq binutils >/dev/null 2>&1 || true
rm -rf /work && mkdir -p /work
# A clean copy (no Windows build outputs, caches or local.properties) with the shared folders the build reads
tar -C /src --exclude='build' --exclude='.gradle' --exclude='.kotlin' --exclude='local.properties' -cf - \
    android luksMusic/SampleScores luksMusic/Assets.xcassets/AppIcon.appiconset | tar -C /work -xf -
cd /work/android
chmod +x gradlew
./gradlew --no-daemon --console=plain -Pluksmusic.desktopOnly=true :desktop:test :desktop:packageDeckTarball
mkdir -p /src/android/desktop/build/dist
cp desktop/build/dist/luksMusic-linux-x64.tar.gz /src/android/desktop/build/dist/
ls -l /src/android/desktop/build/dist/
