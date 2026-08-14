#!/usr/bin/env bash

echo "🔍 Wallpaper klasörü aranıyor..."

# Olası wallpaper klasörleri
POSSIBLE_DIRS=(
    "$HOME/Resimler/Wallpapers"
    "$HOME/Pictures/Wallpapers"
    "$HOME/Wallpapers"
    "$HOME/Resimler"
    "$HOME/Pictures"
)

WALLPAPER_DIR=""

# İlk var olan klasörü bul
for dir in "${POSSIBLE_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        # Klasörde resim var mı kontrol et
        if ls "$dir"/*.{jpg,jpeg,png,webp,gif} 2>/dev/null | head -1 | grep -q .; then
            WALLPAPER_DIR="$dir"
            echo "✅ Wallpaper klasörü bulundu: $WALLPAPER_DIR"
            break
        fi
    fi
done

# Hiç klasör bulunamadıysa, kullanıcıdan al
if [ -z "$WALLPAPER_DIR" ]; then
    echo ""
    echo "❌ Otomatik wallpaper klasörü bulunamadı."
    echo ""
    echo "Lütfen wallpaper klasörünüzün tam yolunu girin:"
    echo "(Örnek: /home/lunanoir/Resimler/Wallpapers)"
    read -r WALLPAPER_DIR
    
    # Klasör yoksa oluştur
    if [ ! -d "$WALLPAPER_DIR" ]; then
        echo "📁 Klasör bulunamadı, oluşturuluyor: $WALLPAPER_DIR"
        mkdir -p "$WALLPAPER_DIR"
    fi
fi

# settings.json'u güncelle
SETTINGS_FILE="$HOME/.config/hypr/settings.json"
if [ -f "$SETTINGS_FILE" ]; then
    echo "📝 settings.json güncelleniyor..."
    
    # jq ile wallpaperDir'i güncelle
    TMP_FILE=$(mktemp)
    jq --arg dir "$WALLPAPER_DIR" '.wallpaperDir = $dir' "$SETTINGS_FILE" > "$TMP_FILE"
    mv "$TMP_FILE" "$SETTINGS_FILE"
    
    echo "✅ settings.json güncellendi: wallpaperDir = $WALLPAPER_DIR"
else
    echo "❌ HATA: settings.json bulunamadı!"
    exit 1
fi

# env.conf'u güncelle
ENV_CONF="$HOME/.config/hypr/config/env.conf"
if [ -f "$ENV_CONF" ]; then
    echo "📝 env.conf güncelleniyor..."
    sed -i "s|env = WALLPAPER_DIR,.*|env = WALLPAPER_DIR,$WALLPAPER_DIR|" "$ENV_CONF"
    echo "✅ env.conf güncellendi"
fi

# Thumbnail cache'i temizle
echo "🗑️  Thumbnail cache temizleniyor..."
CACHE_DIR="$HOME/.cache/quickshell/wallpaper_picker"
rm -rf "$CACHE_DIR/thumbs"/*
rm -rf "$CACHE_DIR/colors_markers"/*
rm -f "$CACHE_DIR/colors.csv"

echo ""
echo "✅ Tüm ayarlar tamamlandı!"
echo ""
echo "Şimdi şunları yapın:"
echo "1. Hyprland'ı reload edin: Super+R"
echo "2. Quickshell'i yeniden başlatın: pkill -f quickshell"
echo "3. Wallpaper picker'ı açın: Super+W"
