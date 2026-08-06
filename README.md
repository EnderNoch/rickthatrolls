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

Są trzy warianty. Wybierasz jeden — workflow sam wykrywa, który.

| wariant | film widoczny w repo? | limit 100 MB? | co ustawiasz |
|---|---|---|---|
| **A** — plik w tym repo | tak | **tak** | nic, po prostu `video.mp4` w katalogu głównym |
| **B** — osobne prywatne repo | **nie** | **tak** | zmienna `MEDIA_REPO` + sekret `MEDIA_TOKEN` |
| **C** — prywatny link | **nie** | nie | sekret `VIDEO_URL` |

Limit 100 MB na plik obowiązuje w gicie zawsze — także w repozytorium prywatnym. Jeśli twój film jest większy, najpierw przepuść go przez `compress.sh` (punkt 2), inaczej zostaje tylko wariant C.

Warianty B i C są opisane w punkcie 4. Domyślnie `.gitignore` blokuje `video.*`, żeby film nie wpadł do repo przez przypadek — jeśli świadomie wybierasz wariant A, usuń te linie z `.gitignore`.

**Wariant A** (film w repo, najprościej):

```bash
git checkout claude/video-player-no-controls-ljw4w5
cp /ścieżka/do/twojego/filmu.mp4 video.mp4
git add -f video.mp4          # -f, bo .gitignore go blokuje
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

## 2. Limity rozmiaru i kompresja

| limit | wartość | dotyczy |
|---|---|---|
| upload przez stronę GitHuba | **25 MB** | „Yowza, that's a big file" |
| ostrzeżenie przy `git push` | 50 MB | |
| **twarde odrzucenie przez gita** | **100 MB** | tak samo w repo publicznym i **prywatnym** |
| zalecany rozmiar całej strony Pages | 1 GB | |
| transfer Pages | 100 GB / miesiąc (miękki) | |

Kluczowe: **limit 100 MB obowiązuje w każdym repozytorium**, więc trzymanie filmu w osobnym prywatnym repo (wariant B) nie omija go ani trochę. Plik ponad 100 MB ma dokładnie dwie drogi: skompresować albo wyprowadzić poza gita (wariant C).

### compress.sh

```bash
./compress.sh moj-film.mp4          # -> video.mp4 o rozmiarze ~45 MB
./compress.sh moj-film.mp4 80       # -> ~80 MB
```

Dwa przebiegi x264 z policzonym bitratem, więc rozmiar wyjściowy jest **przewidywalny** — inaczej niż przy CRF, gdzie wychodzi, ile wyjdzie. Skrypt sam odczytuje długość i rozdzielczość, przelicza bitrate pod zadany limit, skaluje do maks. 1080p i ostrzega, jeśli wyliczony bitrate jest za niski dla materiału.

Bitrate to `rozmiar / długość`, więc długość filmu decyduje o wszystkim:

| długość | cel 45 MB | jakość przy 1080p |
|---|---|---|
| 2 min | ~2900 kb/s | bardzo dobra |
| 5 min | ~1060 kb/s | dobra |
| 20 min | ~170 kb/s | zła — skróć materiał albo zejdź z rozdzielczości |

Skrypt wymaga `ffmpeg` i `ffprobe` (Ubuntu: `apt install ffmpeg`, macOS: `brew install ffmpeg`). Jeśli wolisz klikać, to samo robi **HandBrake** — preset *Fast 1080p30*, tryb *Average Bitrate* z wartością z tabeli powyżej, plus zaznaczone *Web Optimized*.

Kompresja opłaca się nawet gdy plik zmieściłby się w limicie: przy 100 GB transferu miesięcznie film 45 MB wystarcza na ~2270 wejść, a 244 MB tylko na ~420. Widz na komórce też pobiera każdy z tych megabajtów.

### Git LFS — zwykle zła odpowiedź

Workflow robi `checkout` z `lfs: true`, więc pliki LFS są rozpakowywane przed publikacją i **działają** (przy trybie „Deploy from a branch" nie działają — Pages serwuje wtedy sam wskaźnik LFS zamiast filmu). Problem w tym, że darmowy limit LFS to 1 GB miejsca i **1 GB transferu miesięcznie**: przy filmie 240 MB kończy się po czterech pobraniach. Dla tego zastosowania LFS praktycznie zawsze przegrywa z kompresją albo z wariantem C.

## 3. Włączenie GitHub Pages

W repo: **Settings → Pages → Build and deployment → Source: GitHub Actions**.

Workflow (`.github/workflows/pages.yml`) publikuje przy każdym pushu na `main` oraz ręcznie z zakładki Actions. Strona ląduje pod `https://endernoch.github.io/rickthatrolls/`.

Żeby to poszło na produkcję, gałąź `claude/video-player-no-controls-ljw4w5` trzeba zmergować do `main` (albo w workflow zmienić `branches: [main]` na swoją gałąź).

## 4. Film poza repozytorium

Najpierw rozdzielmy dwie rzeczy, bo tylko jedna z nich jest wykonalna:

| | wykonalne? |
|---|---|
| film **nie leży w repozytorium** i nie widać go w historii gita | **tak** — warianty B i C poniżej |
| film **nie da się pobrać** z opublikowanej strony | **nie** — na GitHub Pages nigdy |

Drugiego nie da się obejść żadnym kodem: skoro przeglądarka film odtwarza, to znaczy, że go pobrała. Adres `…/video.mp4` zawsze zwróci plik, a strona Pages na koncie Free i Pro jest publiczna **nawet gdy repozytorium jest prywatne** (prywatne Pages z logowaniem to wyłącznie GitHub Enterprise Cloud). Jeśli film naprawdę nie może wyciec, Pages jest złym miejscem — wtedy potrzebny jest hosting z autoryzacją: Cloudflare Access, S3 z podpisanymi linkami albo prywatny link z Vimeo.

Pierwsze natomiast robi za ciebie workflow. Film jest dokładany dopiero w trakcie wdrożenia, więc nie ma go ani w plikach repo, ani w historii gita, ani w limicie 100 MB.

### Wariant B — osobne prywatne repozytorium (za darmo)

Prywatne repozytoria są bezpłatne, więc film może leżeć w takim, a publiczne repo ze stroną tylko po niego sięga.

1. Załóż prywatne repo, np. `rickthatrolls-media`, i wrzuć do niego `video.mp4`.
2. Wygeneruj token z dostępem do odczytu tamtego repo: **Settings → Developer settings → Personal access tokens → Fine-grained tokens**, `Repository access` = tylko `rickthatrolls-media`, uprawnienie `Contents: Read-only`.
3. W tym repo: **Settings → Secrets and variables → Actions**
   - zakładka **Variables** → `MEDIA_REPO` = `EnderNoch/rickthatrolls-media`
   - zakładka **Secrets** → `MEDIA_TOKEN` = wygenerowany token

Workflow zrobi wtedy `checkout` prywatnego repo do katalogu roboczego i skopiuje film do `_site/`.

### Wariant C — prywatny link

Film leży gdziekolwiek, skąd da się go pobrać jednym `curl` (S3 presigned URL, Dropbox z `?dl=1`, własny serwer). W **Settings → Secrets and variables → Actions → Secrets** ustaw `VIDEO_URL` na ten adres. Sekret nie pojawia się w logach ani na stronie.

Format rozpoznawany jest po rozszerzeniu w adresie — query string i fragment są pomijane, więc `…/film.webm?token=abc` zadziała poprawnie. Adres **bez** rozszerzenia (np. `…/download?id=99`) zostanie zapisany jako `video.mp4`; jeśli to w rzeczywistości webm, przeglądarka go pominie z powodu niezgodnego `type`. Nieosiągalny adres przerywa wdrożenie z błędem, zamiast po cichu opublikować pustą stronę.

### Co jeszcze ogranicza zasięg

Niezależnie od wariantu, w repo jest już:

- `robots.txt` z `Disallow: /` oraz `<meta name="robots" content="noindex, nofollow, noarchive, noimageindex">` — strona nie trafia do Google,
- `<meta name="referrer" content="no-referrer">` — adres nie wycieka w nagłówku do stron, na które ktoś przejdzie dalej,
- pusty `<title>` — zakładka nic nie mówi o zawartości,
- do artefaktu Pages trafia **wyłącznie** `index.html`, `robots.txt`, `.nojekyll` i film — README, LICENSE i workflow nie są publikowane pod adresem strony.

Jeśli ma to wystarczyć jako „nie do znalezienia", nazwij plik losowym ciągiem (np. `a7f3c91e4b2d.mp4`, podmieniając `<source src="...">`) i tak samo nazwij podstronę — wtedy sam adres repo nic nie daje. To zabezpieczenie przez nieoczywistość, nie przez uprawnienia.

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

## 7. Pętla, skalowanie i orientacja

Zapętlenie robi natywny atrybut `loop` na `<video>` — bez linijki JS-a. Sprawdzone na Chromium przez 20 sekund na trzysekundowym filmie: **6 pełnych okrążeń, zero zdarzeń `ended`, zero `pause`**, film ani razu się nie zatrzymał. Przeglądarka po prostu wraca do zera i leci dalej.

Jeśli zależy ci na tym, żeby przejście przez koniec pętli było niewidoczne, warto przy kodowaniu wymusić klatkę kluczową co sekundę (`-g 30 -keyint_min 30` w `ffmpeg`) i zadbać, żeby pierwsza i ostatnia klatka wyglądały podobnie. Sam mechanizm pętli nie ma tu nic do rzeczy — to kwestia materiału.

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
