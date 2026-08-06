# rickthatrolls

Jednoplikowa strona na GitHub Pages, która po wejściu odtwarza film:

- **bez żadnych kontrolek** — nie dlatego, że są blokowane, tylko dlatego, że ich nie ma: brak atrybutu `controls`, brak fokusu, brak celu dla kursora,
- **non stop w pętli** — jedyne, co jeszcze potrafi zatrzymać film (uśpienie ekranu, klawisz multimedialny), wraca do odtwarzania,
- **na całe okno** — `object-fit: cover`, więc nie ma czarnych pasków; obrót telefonu, zmiana rozmiaru okna i chowające się paski przeglądarki są obsłużone,
- **na domyślnej głośności** — z zastrzeżeniem opisanym niżej (autoplay z dźwiękiem),
- jedyne wyjście to zamknięcie karty / cofnięcie się ze strony.

Działa na każdym urządzeniu z przeglądarką — nie ma tu żadnych bibliotek ani zależności, tylko `index.html`.

---

## 1. Dodanie filmu

Wrzuć plik do repozytorium jako **`video.mp4`** (w katalogu głównym) i gotowe — nic więcej nie trzeba zmieniać.

```bash
git checkout claude/video-player-no-controls-ljw4w5
cp /ścieżka/do/twojego/filmu.mp4 video.mp4
git add video.mp4
git commit -m "Add video"
git push -u origin claude/video-player-no-controls-ljw4w5
```

Można też przeciągnąć plik przez WWW: **Add file → Upload files** w interfejsie GitHuba (limit 25 MB na plik przy uploadzie przez przeglądarkę — większe pliki tylko przez `git push`).

Obsługiwane są też inne nazwy/ścieżki — `index.html` po kolei próbuje:

| kolejność | plik |
|---|---|
| 1 | `video.mp4` |
| 2 | `media/video.mp4` |
| 3 | `video.webm` |
| 4 | `media/video.webm` |

Jeśli chcesz inną nazwę, zmień linie `<source src="...">` w `index.html` (są opisane komentarzem). Gdy żaden plik nie zostanie znaleziony, strona po ~4 s wyświetla komunikat zamiast czarnego ekranu.

## 2. Limity rozmiaru

To jest ten punkt, o który pytałeś — **30 MB to limit załącznika w czacie, a nie limit GitHuba**. Na GitHubie obowiązuje:

| limit | wartość |
|---|---|
| ostrzeżenie przy `git push` | 50 MB |
| **twarde odrzucenie pliku** | **100 MB** |
| zalecany rozmiar całej strony Pages | 1 GB |
| transfer Pages | 100 GB / miesiąc (miękki) |

Czyli: **plik do 100 MB wrzucasz normalnym `git push`** i nic więcej nie musisz robić.

Jeśli film jest większy niż 100 MB, masz dwie drogi:

**a) Skompresuj** (zwykle wystarcza — 1080p, kilka minut, CRF 26 to zwykle 30–60 MB):

```bash
ffmpeg -i oryginal.mp4 \
  -vcodec libx264 -crf 26 -preset slow -pix_fmt yuv420p \
  -vf "scale='min(1920,iw)':-2" \
  -acodec aac -b:a 128k \
  -movflags +faststart \
  video.mp4
```

`-movflags +faststart` jest istotny: przenosi indeks na początek pliku, dzięki czemu film startuje od razu, zamiast po pobraniu całości.

**b) Git LFS** — workflow w `.github/workflows/pages.yml` robi `checkout` z `lfs: true`, więc pliki LFS są rozpakowywane przed publikacją i **działają** (przy trybie „Deploy from a branch" nie działają — Pages serwuje wtedy sam wskaźnik LFS zamiast filmu). Uwaga: darmowy limit LFS to 1 GB miejsca i 1 GB transferu miesięcznie, co przy stronie z filmem kończy się bardzo szybko.

## 3. Włączenie GitHub Pages

W repo: **Settings → Pages → Build and deployment → Source: GitHub Actions**.

Workflow (`.github/workflows/pages.yml`) publikuje przy każdym pushu na `main` oraz ręcznie z zakładki Actions. Strona ląduje pod `https://endernoch.github.io/rickthatrolls/`.

Żeby to poszło na produkcję, gałąź `claude/video-player-no-controls-ljw4w5` trzeba zmergować do `main` (albo w workflow zmienić `branches: [main]` na swoją gałąź).

## 4. ⚠️ Plik wideo NIE będzie prywatny

Pisałeś, że plik nie może być publiczny — i tu jest realny konflikt z GitHub Pages, więc mówię wprost:

**Strona GitHub Pages na koncie Free i Pro jest zawsze publiczna, nawet jeśli repozytorium jest prywatne.** Każdy, kto zna adres, może wejść i pobrać `video.mp4` bezpośrednio. Prywatne Pages (z logowaniem do organizacji) to funkcja wyłącznie GitHub Enterprise Cloud.

Co jest w tym repo zrobione, żeby przynajmniej ograniczyć zasięg:

- `robots.txt` z `Disallow: /` oraz `<meta name="robots" content="noindex, nofollow, noarchive, noimageindex">` — strona nie trafia do Google,
- `<meta name="referrer" content="no-referrer">` — adres nie wycieka w nagłówkach do stron, na które ktoś przejdzie dalej,
- pusty `<title>` — nic nie mówi o zawartości.

Co możesz dorobić sam, jeśli to ma wystarczyć jako „nie do znalezienia":

- nazwij plik losowym ciągiem, np. `a7f3c91e4b2d.mp4`, i podmień `<source src="...">` — wtedy trzeba znać dokładny URL, a nie tylko domenę,
- nazwij tak samo podstronę (`a7f3c91e4b2d/index.html` zamiast `index.html`) — wtedy sam adres repo nic nie daje.

To jest zabezpieczenie przez nieoczywistość, nie przez uprawnienia. **Jeśli film naprawdę nie może wyciec, GitHub Pages nie jest właściwym miejscem** — potrzebny jest hosting z logowaniem (np. Cloudflare Access, S3 z podpisanymi linkami, albo prywatny link z Vimeo).

## 5. Dźwięk i autoplay — jedyne ograniczenie, którego nie da się obejść

Wszystkie przeglądarki (Chrome, Safari, Firefox, Edge) **blokują automatyczne odtwarzanie z dźwiękiem**, dopóki użytkownik nie wejdzie w interakcję ze stroną. To zabezpieczenie w silniku przeglądarki, nie coś, co da się wyłączyć z poziomu HTML/JS.

Strona radzi sobie z tym tak:

1. Najpierw próbuje wystartować od razu z dźwiękiem. Jeśli użytkownik był już wcześniej na tej domenie i coś tam klikał, przeglądarka to przepuści i film leci z dźwiękiem od pierwszej klatki — bez żadnej akcji z jego strony.
2. Jeśli przeglądarka odmówi — film **i tak startuje natychmiast**, tylko wyciszony, a na dole pojawia się mała plakietka „Dotknij, aby włączyć dźwięk".
3. **Dowolne** dotknięcie / kliknięcie / naciśnięcie klawisza włącza dźwięk na głośności 1.0 i plakietka znika. Nie trzeba trafiać w przycisk — cały ekran jest aktywny.

Od tego momentu głośność jest zablokowana: każda próba zmiany lub wyciszenia jest cofana przez handler `volumechange`.

## 6. Dlaczego nie ma czego blokować

Nic tu nie jest „zablokowane" — funkcji po prostu nie ma. To ważna różnica: blokada to kod, który trzeba utrzymywać i który zawsze da się obejść, a brak funkcji nie ma jak zawieść.

| czego nie ma | dlaczego |
|---|---|
| pasek sterowania, pauza, suwak głośności, przewijanie | brak atrybutu `controls` — przeglądarka nie rysuje żadnego UI |
| reakcja na klawiaturę (spacja, `k`, `m`, `f`, strzałki…) | `<video>` bez `controls` **nie przyjmuje fokusu**, więc klawisze nigdy do niego nie trafiają |
| menu kontekstowe „Pokaż elementy sterujące", „Zapisz wideo jako…", „Zapętl" | `pointer-events: none` — wideo nie jest celem trafienia, prawy klik ląduje na `<body>` |
| Picture-in-Picture, AirPlay, Chromecast | atrybuty `disablepictureinpicture` i `disableremoteplayback` |
| przewijanie strony, pinch-zoom, zaznaczanie | `overflow: hidden`, `user-select: none`, `user-scalable=no` |
| duży przycisk „play" iOS Safari | `::-webkit-media-controls-start-playback-button { display: none }` |

Sprawdziłem to na Chromium zamiast zakładać: goły `<video>` bez `controls` po `.focus()` zostawia `document.activeElement` na `BODY` i nie reaguje na spację, `k`, `p`, `m`, `f`, strzałki, `j`/`l` ani cyfry — te skróty to funkcje odtwarzacza YouTube, nie przeglądarki. Klik i dwuklik też nic nie robią. Kod, który je „blokował", bronił przed czymś, czego nie ma.

W JS zostały tylko trzy rzeczy, których nie da się osiągnąć samym brakiem funkcji:

1. **Powrót po pauzie.** Strona nie ma czym zatrzymać filmu, ale przeglądarka ma: uśpienie ekranu, przełączenie karty, wyciszenie w tle. Leci wtedy zdarzenie `pause` i trzeba wrócić do odtwarzania — plus `visibilitychange` i `pageshow` przy powrocie oraz `stalled`/`error` przy zerwanej sieci.
2. **Klawisze multimedialne, ekran blokady, przycisk na słuchawkach.** Jedyne sterowanie spoza strony, którego nie da się usunąć. Handlery `mediaSession` mają pauzę przemapowaną na odtwarzanie.
3. **Autoodtwarzanie z dźwiękiem** — opisane w punkcie 5.

Czego zatrzymać się **nie da** i nie ma na to sposobu w żadnej technologii webowej: zamknięcie karty, przycisk wstecz, wyciszenie karty z poziomu przeglądarki lub systemu, wyłączenie JS, DevTools, rozszerzenia. Zgodnie z tym, co pisałeś — to jest oczekiwane wyjście ze strony.

## 7. Skalowanie i orientacja

- `position: fixed` + `100dvw`/`100dvh` — `dvh` ignoruje chowające się paski przeglądarki na mobile, więc nie ma „skoku" wysokości przy scrollu.
- `object-fit: cover` — kadr jest przycinany tak, żeby wypełnić okno. **Żadnych czarnych pasków w żadnej orientacji.** Jeśli wolisz zobaczyć cały kadr i zgodzić się na paski, zmień w `index.html` `object-fit: cover` na `contain`.
- Po `orientationchange` wymiary są przeliczane od razu oraz po 100/400/900 ms — iOS Safari raportuje nowy rozmiar dopiero po animacji obrotu i bez tego zostaje pusty pasek.
- Nasłuch na `visualViewport` łapie też pojawienie się klawiatury i pasków systemowych.

## 8. Konfiguracja

Na górze skryptu w `index.html`:

```js
var VOLUME          = 1.0;   // głośność po odblokowaniu dźwięku
var AUTO_FULLSCREEN = false; // true = pierwsze dotknięcie wchodzi w pełny ekran
```

`AUTO_FULLSCREEN = true` dodatkowo próbuje zablokować orientację w poziomie (`screen.orientation.lock`) — działa na Androidzie, iOS to ignoruje.

## 9. Test lokalny

Nie otwieraj `index.html` przez `file://` — autoplay i część API zachowują się tam inaczej niż na Pages. Uruchom lokalny serwer:

```bash
python3 -m http.server 8000
# http://localhost:8000
```
