#!/usr/bin/env bash

WALLPAPER_DIR="/home/lunanoir/.wallpaper-engine"
THUMB_DIR="$HOME/.cache/quickshell/wallpaper_picker/thumbs"

echo "🎨 Thumbnail'ler oluşturuluyor..."
echo "📂 Kaynak: $WALLPAPER_DIR"
echo "📂 Hedef: $THUMB_DIR"
echo ""

mkdir -p "$THUMB_DIR"

# ImageMagick komutunu belirle
if command -v magick &> /dev/null; then
    CMD="magick"
elif command -v convert &> /dev/null; then
    CMD="convert"
else
    echo "❌ ImageMagick bulunamadı!"
    echo "Yüklemek için: sudo pacman -S imagemagick"
    exit 1
fi

# Resim dosyalarını say
total=$(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" \) 2>/dev/null | wc -l)

echo "Toplam $total resim bulundu"
echo ""

count=0

# Her resim için thumbnail oluştur
find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" \) 2>/dev/null | while IFS= read -r img; do
    filename=$(basename "$img")
    thumb="$THUMB_DIR/$filename"
    
    # Thumbnail yoksa oluştur
    if [ ! -f "$thumb" ]; then
        $CMD "$img" -resize x420 -quality 70 "$thumb" 2>/dev/null && {
            count=$((count + 1))
            echo "✓ [$count/$total] $filename"
        } || {
            echo "✗ Hata: $filename"
        }
    else
        count=$((count + 1))
        echo "⊘ [$count/$total] $filename (zaten var)"
    fi
done

echo ""
echo "✅ Thumbnail oluşturma tamamlandı!"
echo ""

# Sonuçları kontrol et
final_count=$(ls -1 "$THUMB_DIR" 2>/dev/null | wc -l)
echo "📊 Toplam thumbnail: $final_count"
echo ""
echo "Şimdi şunları yapın:"
echo "1. pkill -f quickshell"
echo "2. Super+W ile wallpaper picker'ı açın"
