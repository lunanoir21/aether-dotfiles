#!/usr/bin/env bash

echo "🎨 Wallpaper Engine sistemi başlatılıyor..."
echo ""

# Wallpaper engine için özel klasör
WALLPAPER_ENGINE_DIR="$HOME/.wallpaper-engine"

# Klasörü oluştur
if [ ! -d "$WALLPAPER_ENGINE_DIR" ]; then
    echo "📁 Wallpaper Engine klasörü oluşturuluyor: $WALLPAPER_ENGINE_DIR"
    mkdir -p "$WALLPAPER_ENGINE_DIR"
    echo "✅ Klasör oluşturuldu"
else
    echo "✅ Wallpaper Engine klasörü mevcut: $WALLPAPER_ENGINE_DIR"
fi

# Örnek wallpaper'lar için link oluştur (isteğe bağlı)
echo ""
echo "📸 Örnek wallpaper kaynakları:"
echo "   - Kendi resimlerinizi buraya koyabilirsiniz: $WALLPAPER_ENGINE_DIR"
echo "   - Veya mevcut resimlerinizi sembolik link ile ekleyebilirsiniz"
echo ""

# Kullanıcının mevcut resim klasörlerini tespit et
if [ -d "$HOME/Resimler" ]; then
    echo "   Resimler klasörü bulundu: $HOME/Resimler"
    echo "   Buradan resim eklemek ister misiniz? (e/h)"
    read -r answer
    if [[ "$answer" =~ ^[Ee]$ ]]; then
        # Resimler klasöründeki resim dosyalarını kopyala
        echo "   📋 Resimler kopyalanıyor..."
        find "$HOME/Resimler" -maxdepth 2 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) -exec cp {} "$WALLPAPER_ENGINE_DIR/" \; 2>/dev/null
        count=$(ls -1 "$WALLPAPER_ENGINE_DIR"/*.{jpg,jpeg,png,webp} 2>/dev/null | wc -l)
        echo "   ✅ $count resim kopyalandı"
    fi
fi

# settings.json'u güncelle
echo ""
echo "📝 Hyprland ayarları güncelleniyor..."
SETTINGS_FILE="$HOME/.config/hypr/settings.json"
if [ -f "$SETTINGS_FILE" ]; then
    TMP_FILE=$(mktemp)
    jq --arg dir "$WALLPAPER_ENGINE_DIR" '.wallpaperDir = $dir' "$SETTINGS_FILE" > "$TMP_FILE"
    mv "$TMP_FILE" "$SETTINGS_FILE"
    echo "✅ settings.json güncellendi"
else
    echo "❌ HATA: settings.json bulunamadı!"
    exit 1
fi

# env.conf'u güncelle
ENV_CONF="$HOME/.config/hypr/config/env.conf"
if [ -f "$ENV_CONF" ]; then
    sed -i "s|env = WALLPAPER_DIR,.*|env = WALLPAPER_DIR,$WALLPAPER_ENGINE_DIR|" "$ENV_CONF"
    echo "✅ env.conf güncellendi"
fi

# .zshrc'yi güncelle (varsa)
if [ -f "$HOME/.zshrc" ]; then
    if grep -q "^export WALLPAPER_DIR=" "$HOME/.zshrc"; then
        sed -i "s|^export WALLPAPER_DIR=.*|export WALLPAPER_DIR=\"$WALLPAPER_ENGINE_DIR\"|" "$HOME/.zshrc"
    else
        echo "export WALLPAPER_DIR=\"$WALLPAPER_ENGINE_DIR\"" >> "$HOME/.zshrc"
    fi
    echo "✅ .zshrc güncellendi"
fi

# Thumbnail cache'i temizle
echo ""
echo "🗑️  Eski cache temizleniyor..."
CACHE_DIR="$HOME/.cache/quickshell/wallpaper_picker"
rm -rf "$CACHE_DIR/thumbs"/*
rm -rf "$CACHE_DIR/colors_markers"/*
rm -f "$CACHE_DIR/colors.csv"
rm -f "$CACHE_DIR/colors.csv.bak"
echo "✅ Cache temizlendi"

# Wallpaper init flag'ini sıfırla (yeni bir wallpaper seçilsin)
STATE_DIR="$HOME/.local/state/quickshell/wallpaper_picker"
rm -f "$STATE_DIR/wallpaper_initialized"
echo "✅ Init flag sıfırlandı"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Wallpaper Engine kurulumu tamamlandı!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📂 Wallpaper klasörü: $WALLPAPER_ENGINE_DIR"
echo ""
echo "🎯 Nasıl kullanılır:"
echo "   1. Resimlerinizi buraya ekleyin: $WALLPAPER_ENGINE_DIR"
echo "   2. Hyprland'ı reload edin: Super+R"
echo "   3. Wallpaper picker'ı açın: Super+W"
echo "   4. Artı (+) butonuna tıklayarak daha fazla resim ekleyebilirsiniz"
echo ""
echo "💡 İpucu: Artı butonu ile eklediğiniz resimler otomatik olarak"
echo "   $WALLPAPER_ENGINE_DIR klasörüne kopyalanacak!"
echo ""
