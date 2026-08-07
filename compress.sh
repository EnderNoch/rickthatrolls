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
# Osobne wywołania i wyłącznie format default=nw=1:nk=1. Pisarz csv zmieniał
# składnię opcji między wersjami ffmpeg — na 8.x `csv=p=0:s=' '` już nie
# przechodzi ("Failed to parse option string provided to textformat context").
probe() {
  ffprobe -v error "$@" -of default=nw=1:nk=1 "$IN" 2>/dev/null | head -1
}
DURATION=$(probe -show_entries format=duration)
WIDTH=$(probe  -select_streams v:0 -show_entries stream=width)
HEIGHT=$(probe -select_streams v:0 -show_entries stream=height)
WIDTH=${WIDTH:-?}
HEIGHT=${HEIGHT:-?}

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

printf 'Wyjście : %s — cel %s MB, bitrate wideo %s kb/s\n' "$OUT" "$TARGET_MB" "$VIDEO_KBPS"

# ---- wypalone czarne pasy ----
# Materiał 4:3 dopchany do 16:9 (albo odwrotnie) ma czarne pasy w samych
# klatkach. Żadne tło strony ich nie usunie, a bitrate idzie na kodowanie
# czerni. cropdetect znajduje prostokąt z obrazem.
#
# Próbki z kilku miejsc i UNIA wyników, nie ostatni pomiar: przy ciemnej
# scenie cropdetect potrafi uznać część obrazu za pas i wyciąć za dużo.
CROP=""
if [ "${NO_CROP:-0}" != "1" ]; then
  X1=999999; Y1=999999; X2=0; Y2=0; ANY=0
  for FRAC in 10 30 50 70 90; do
    T=$(awk -v d="$DURATION" -v f="$FRAC" 'BEGIN { printf "%.1f", d * f / 100 }')
    LINE=$(ffmpeg -hide_banner -ss "$T" -i "$IN" -vf cropdetect=24:2:0 \
             -frames:v 60 -f null - 2>&1 | grep -o 'crop=[0-9]*:[0-9]*:[0-9]*:[0-9]*' | tail -1)
    [ -n "$LINE" ] || continue
    set -- $(echo "${LINE#crop=}" | tr ':' ' ')
    [ "$1" -gt 0 ] 2>/dev/null || continue
    ANY=1
    [ "$3" -lt "$X1" ] && X1=$3
    [ "$4" -lt "$Y1" ] && Y1=$4
    [ $(( $3 + $1 )) -gt "$X2" ] && X2=$(( $3 + $1 ))
    [ $(( $4 + $2 )) -gt "$Y2" ] && Y2=$(( $4 + $2 ))
  done
  if [ "$ANY" = "1" ]; then
    CW=$(( X2 - X1 )); CH=$(( Y2 - Y1 ))
    CW=$(( CW - CW % 2 )); CH=$(( CH - CH % 2 ))   # parzyste wymiary dla yuv420p
    if [ "$CW" -lt "${WIDTH:-0}" ] || [ "$CH" -lt "${HEIGHT:-0}" ]; then
      CROP="crop=$CW:$CH:$X1:$Y1"
      printf 'Kadr    : wykryto czarne pasy — przycinam do %sx%s (offset %s,%s)\n' \
             "$CW" "$CH" "$X1" "$Y1"
    fi
  fi
fi
echo

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
[ -n "$CROP" ] && VF="$CROP,$VF"      # przycinanie zawsze przed skalowaniem
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
