#!/bin/sh
# Builds build/Termnotes.app (Apple Silicon + Intel) and build/Termnotes.zip
set -e
cd "$(dirname "$0")"

APP=build/Termnotes.app
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -target arm64-apple-macos12 app/main.swift -o build/Termnotes-arm64
swiftc -O -target x86_64-apple-macos12 app/main.swift -o build/Termnotes-x86_64
lipo -create build/Termnotes-arm64 build/Termnotes-x86_64 -output "$APP/Contents/MacOS/Termnotes"
rm build/Termnotes-arm64 build/Termnotes-x86_64

cp app/Info.plist "$APP/Contents/"
cp index.html "$APP/Contents/Resources/"
[ -f app/AppIcon.icns ] && cp app/AppIcon.icns "$APP/Contents/Resources/"

codesign --force --deep --sign - "$APP"
ditto -c -k --keepParent "$APP" build/Termnotes.zip
echo "Built $APP and build/Termnotes.zip"
