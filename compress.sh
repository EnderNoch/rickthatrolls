#!/usr/bin/env bash
#
# Kompresja filmu pod GitHub Pages do zadanego rozmiaru.
#
#   ./compress.sh moj-film.mp4              -> video.mp4 o rozmiarze ~45 MB
#   ./compress.sh moj-film.mp4 80           -> ~80 MB
#   ./compress.sh moj-film.mp4 80 out.mp4   -> ~80 MB pod inną nazwą
#
# Dwa przebiegi x264 z zadanym bitrate'em, więc rozmiar wyjściowy jest
# przewidywalny (w przeciwieństwie do CRF, gdzie wychodzi, ile wyjdzie).
#
set -euo pipefail

IN=${1:-}
TARGET_MB=${2:-45}
OUT=${3:-video.mp4}

AUDIO_KBPS=128      # bitrate ścieżki dźwiękowej
OVERHEAD=0.97       # margines na narzut kontenera MP4
MAX_WIDTH=1920      # wyżej niż 1080p nie ma sensu dla filmu w tle

die() { echo "BŁĄD: $*" >&2; exit 1; }

[ -n "$IN" ] || die "podaj plik wejściowy: ./compress.sh moj-film.mp4 [MB] [wyjście]"
[ -f "$IN" ] || die "nie ma pliku: $IN"
command -v ffmpeg  >/dev/null || die "brak ffmpeg (Ubuntu: apt install ffmpeg, macOS: brew install ffmpeg)"
command -v ffprobe >/dev/null || die "brak ffprobe (jest w tej samej paczce co ffmpeg)"

# ---- co mamy na wejściu ----
# Dwa osobne wywołania, żeby nie zależeć od kolejności sekcji w wyjściu ffprobe.
DURATION=$(ffprobe -v error -show_entries format=duration \
             -of default=nw=1:nk=1 "$IN" || true)
read -r WIDTH HEIGHT <<EOF
$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height \
    -of csv=p=0:s=' ' "$IN" || true)
EOF

case "${DURATION:-}" in
  ''|N/A|0*) die "nie udało się odczytać długości filmu z $IN" ;;
esac
IN_MB=$(du -m "$IN" | cut -f1)

printf 'Wejście : %s — %s MB, %sx%s, %.1f s\n' "$IN" "$IN_MB" "$WIDTH" "$HEIGHT" "$DURATION"

# ---- ile bitrate'u się mieści ----
# MB -> kbit: MB * 1024 * 8 = MB * 8192
VIDEO_KBPS=$(awk -v mb="$TARGET_MB" -v d="$DURATION" -v a="$AUDIO_KBPS" -v o="$OVERHEAD" \
  'BEGIN { printf "%d", (mb * 8192 * o / d) - a }')

[ "$VIDEO_KBPS" -gt 0 ] || die "film jest za długi na $TARGET_MB MB — zwiększ limit albo skróć materiał"

printf 'Wyjście : %s — cel %s MB, bitrate wideo %s kb/s\n\n' "$OUT" "$TARGET_MB" "$VIDEO_KBPS"

if [ "$VIDEO_KBPS" -lt 800 ]; then
  echo "UWAGA: $VIDEO_KBPS kb/s to mało jak na $WIDTH""x""$HEIGHT."
  echo "       Obraz będzie się rozmywał w ruchu. Rozważ wyższy limit MB,"
  echo "       krótszy materiał albo niższą rozdzielczość (MAX_WIDTH w tym pliku)."
  echo
fi

# ---- kodowanie ----
# -vf scale: zmniejsza tylko jeśli film jest szerszy niż MAX_WIDTH, -2 pilnuje
#            parzystej wysokości (wymóg yuv420p)
# -g/-keyint_min: klatka kluczowa co sekundę — szybszy start i czystsze
#            wznowienie obrazu w miejscu zapętlenia
# -movflags +faststart: indeks na początek pliku, żeby film ruszał od razu
#            zamiast po pobraniu całości
VF="scale='min($MAX_WIDTH,iw)':-2"
COMMON=(-c:v libx264 -b:v "${VIDEO_KBPS}k" -preset slow -pix_fmt yuv420p
        -profile:v high -level 4.0 -vf "$VF" -g 30 -keyint_min 30)

echo "[1/2] pierwszy przebieg..."
ffmpeg -hide_banner -loglevel error -stats -y -i "$IN" "${COMMON[@]}" \
  -pass 1 -an -f mp4 /dev/null

echo "[2/2] drugi przebieg..."
ffmpeg -hide_banner -loglevel error -stats -y -i "$IN" "${COMMON[@]}" \
  -pass 2 -c:a aac -b:a "${AUDIO_KBPS}k" -movflags +faststart "$OUT"

rm -f ffmpeg2pass-0.log ffmpeg2pass-0.log.mbtree

OUT_MB=$(du -m "$OUT" | cut -f1)
echo
printf 'Gotowe: %s MB -> %s MB\n' "$IN_MB" "$OUT_MB"

if [ "$OUT_MB" -ge 100 ]; then
  echo "Nadal ponad 100 MB — git tego nie przyjmie. Uruchom ponownie z niższym limitem."
elif [ "$OUT_MB" -ge 50 ]; then
  echo "Poniżej twardego limitu 100 MB, ale git wypisze ostrzeżenie przy 50 MB."
else
  echo "Mieści się bez ostrzeżeń. Teraz: git add -f $OUT"
fi
