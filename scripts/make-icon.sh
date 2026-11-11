#!/bin/sh
# Regenerates every size in Hours/Assets.xcassets/AppIcon.appiconset from
# scripts/icon.svg. Uses sips, which ships with macOS and reads SVG.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
svg="$root/scripts/icon.svg"
out="$root/Hours/Assets.xcassets/AppIcon.appiconset"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$out"
sips -s format png "$svg" --out "$tmp/1024.png" >/dev/null

for px in 16 32 64 128 256 512 1024; do
  sips -z "$px" "$px" "$tmp/1024.png" --out "$tmp/$px.png" >/dev/null
done

for pt in 16 32 128 256 512; do
  cp "$tmp/$pt.png" "$out/icon_${pt}x${pt}.png"
  cp "$tmp/$((pt * 2)).png" "$out/icon_${pt}x${pt}@2x.png"
done

cat > "$out/Contents.json" <<'JSON'
{
  "images" : [
    { "filename" : "icon_16x16.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_16x16@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32x32.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_32x32@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128x128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128x128@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256x256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256x256@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512x512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512x512@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON

cat > "$root/Hours/Assets.xcassets/Contents.json" <<'JSON'
{
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON

echo "Wrote $(ls "$out" | grep -c png) PNGs to $out"
