#!/usr/bin/env bash

echo "🔍 Wallpaper Picker Tanılama"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 1. settings.json kontrolü
echo "1️⃣ settings.json wallpaperDir:"
WALLPAPER_DIR=$(jq -r '.wallpaperDir' "$HOME/.config/hypr/settings.json" 2>/dev/null)
echo "   $WALLPAPER_DIR"

if [ ! -d "$WALLPAPER_DIR" ]; then
    echo "   ❌ HATA: Klasör bulunamadı!"
    echo ""
    echo "Klasörü oluşturmak ister misiniz? (e/h)"
    read -r answer
    if [[ "$answer" =~ ^[Ee]$ ]]; then
        mkdir -p "$WALLPAPER_DIR"
        echo "   ✅ Klasör oluşturuldu"
    fi
else
    echo "   ✅ Klasör var"
fi
echo ""

# 2. Klasördeki dosyalar
echo "2️⃣ Wallpaper klasöründeki dosyalar:"
if [ -d "$WALLPAPER_DIR" ]; then
    file_count=$(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" \) 2>/dev/null | wc -l)
    echo "   Toplam resim: $file_count"
    
    if [ $file_count -eq 0 ]; then
        echo "   ❌ Klasörde hiç resim yok!"
        echo ""
        echo "   Test resmi indirmek ister misiniz? (e/h)"
        read -r answer
        if [[ "$answer" =~ ^[Ee]$ ]]; then
            echo "   📥 Test resmi indiriliyor..."
            curl -L "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=1920&q=80" -o "$WALLPAPER_DIR/test-mountain.jpg" 2>/dev/null
            if [ -f "$WALLPAPER_DIR/test-mountain.jpg" ]; then
                echo "   ✅ Test resmi indirildi: test-mountain.jpg"
            else
                echo "   ❌ İndirme başarısız"
            fi
        fi
    else
        echo "   ✅ İlk 5 dosya:"
        ls -1 "$WALLPAPER_DIR" | grep -iE '\.(jpg|jpeg|png|webp|gif)$' | head -5 | sed 's/^/      /'
    fi
fi
echo ""

# 3. env.conf kontrolü
echo "3️⃣ env.conf WALLPAPER_DIR:"
grep "WALLPAPER_DIR" "$HOME/.config/hypr/config/env.conf" 2>/dev/null || echo "   ❌ Bulunamadı"
echo ""

# 4. Thumbnail cache
echo "4️⃣ Thumbnail cache durumu:"
THUMB_DIR="$HOME/.cache/quickshell/wallpaper_picker/thumbs"
if [ -d "$THUMB_DIR" ]; then
    thumb_count=$(ls -1 "$THUMB_DIR" 2>/dev/null | wc -l)
    echo "   Thumbnail sayısı: $thumb_count"
    if [ $thumb_count -eq 0 ]; then
        echo "   ⚠️  Thumbnail'ler oluşturulmamış!"
    else
        echo "   ✅ Thumbnail'ler var"
    fi
else
    echo "   ❌ Thumbnail klasörü yok"
    mkdir -p "$THUMB_DIR"
    echo "   ✅ Thumbnail klasörü oluşturuldu"
fi
echo ""

# 5. Gerekli araçlar
echo "5️⃣ Gerekli araçların kontrolü:"
if command -v magick &> /dev/null; then
    echo "   ✅ ImageMagick (magick): $(magick --version | head -1)"
elif command -v convert &> /dev/null; then
    echo "   ✅ ImageMagick (convert): $(convert --version | head -1)"
else
    echo "   ❌ ImageMagick YOK! (thumbnail'ler için gerekli)"
    echo "      Yüklemek için: sudo pacman -S imagemagick"
fi

if command -v ffmpeg &> /dev/null; then
    echo "   ✅ ffmpeg: $(ffmpeg -version | head -1 | cut -d' ' -f3)"
else
    echo "   ⚠️  ffmpeg yok (video thumbnail için gerekli)"
fi
echo ""

# 6. Thumbnail oluşturmayı test et
echo "6️⃣ Manuel thumbnail oluşturma testi:"
if [ -d "$WALLPAPER_DIR" ] && [ $file_count -gt 0 ]; then
    test_img=$(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) | head -1)
    if [ -n "$test_img" ]; then
        test_name=$(basename "$test_img")
        echo "   Test resmi: $test_name"
        
        if command -v magick &> /dev/null; then
            echo "   Thumbnail oluşturuluyor..."
            magick "$test_img" -resize x420 -quality 70 "$THUMB_DIR/test_thumb.jpg" 2>&1
            
            if [ -f "$THUMB_DIR/test_thumb.jpg" ]; then
                size=$(du -h "$THUMB_DIR/test_thumb.jpg" | cut -f1)
                echo "   ✅ Thumbnail oluşturuldu! (Boyut: $size)"
            else
                echo "   ❌ Thumbnail oluşturulamadı!"
            fi
        else
            echo "   ❌ ImageMagick yok, thumbnail oluşturulamıyor"
        fi
    fi
fi
echo ""

# 7. qs_manager.sh'yi manuel test et
echo "7️⃣ Thumbnail hazırlama scriptini test et:"
echo "   Şu komutu çalıştırarak thumbnail'leri manuel oluşturabilirsiniz:"
echo "   bash ~/.config/hypr/scripts/qs_manager.sh toggle wallpaper"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Özet:"
echo "   Wallpaper klasörü: $WALLPAPER_DIR"
echo "   Resim sayısı: $file_count"
echo "   Thumbnail sayısı: $thumb_count"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
