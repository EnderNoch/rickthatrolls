# [rickthatrolls](https://endernoch.github.io/rickthatrolls/)

**English** · [Polski ↓](#polski)

A single-file GitHub Pages site that plays a video the moment you land on it:

- **no controls at all** — not because they are blocked, but because they do not exist: no `controls` attribute, no focus, no hit target for the cursor,
- **looping forever** — the only things that can still stop it (screen sleep, a media key) are turned back into playback,
- **fills the window** — the whole frame stays visible at any window size; phone rotation, window resizing and collapsing browser chrome are handled,
- **at full volume** — with the one caveat described below (autoplay with sound),
- **the page itself offers no way to stop it** — but the browser around it does, and that part is not blocked. See [browser controls still work](#browser-controls-still-work).

Works on any device with a browser — no libraries, no dependencies, just `index.html`.

---

## 1. Adding the video

There are three variants. Pick one; the workflow detects which.

| variant | video visible in the repo? | 100 MB limit? | what you configure |
|---|---|---|---|
| **A** — file in this repo | yes | **yes** | nothing, just `video.mp4` in the root |
| **B** — separate private repo | **no** | **yes** | `MEDIA_REPO` variable + `MEDIA_TOKEN` secret |
| **C** — private link | **no** | no | `VIDEO_URL` secret |

Git's 100 MB per-file limit applies to **every** repository, private ones included. If your video is bigger, run it through `compress.sh` first (section 2), otherwise only variant C is left.

Variants B and C are described in section 4. By default `.gitignore` blocks `video.*` so the file cannot be committed by accident — if you deliberately choose variant A, delete those lines from `.gitignore`.

**Variant A** (video in the repo, simplest):

```bash
cp /path/to/your/movie.mp4 video.mp4
git add -f video.mp4
git commit -m "Add video"
git push
```

`-f` is needed because `.gitignore` blocks the file. You can also drag it in through the web UI: **Add file → Upload files** (25 MB per file through the browser — anything larger has to go through `git push`).

Other names and paths work too — `index.html` tries these in order:

| order | file |
|---|---|
| 1 | `video.mp4` |
| 2 | `media/video.mp4` |
| 3 | `video.webm` |
| 4 | `media/video.webm` |

For a different name, edit the `<source src="...">` lines in `index.html` (they are commented). If no file is found, the page shows a message after ~4 s instead of a black screen.

## 2. Size limits and compression

| limit | value | applies to |
|---|---|---|
| upload through the GitHub website | **25 MB** | "Yowza, that's a big file" |
| warning on `git push` | 50 MB | |
| **hard rejection by git** | **100 MB** | identical in public and **private** repos |
| recommended total Pages site size | 1 GB | |
| Pages bandwidth | 100 GB / month (soft) | |

The key point: **the 100 MB limit applies to every repository**, so keeping the video in a separate private repo (variant B) does not raise it at all. A file over 100 MB has exactly two options: compress it, or keep it out of git entirely (variant C).

### compress.sh

```bash
./compress.sh my-movie.mp4          # -> video.mp4 at roughly 45 MB
./compress.sh my-movie.mp4 80       # -> roughly 80 MB
```

Two-pass x264 at a computed bitrate, so the output size is **predictable** — unlike CRF, where you get whatever you get. The script reads duration and resolution itself, works out the bitrate for the target size, scales down to at most 1080p, and warns when the computed bitrate is too low for the material.

It also **removes black bars baked into the frames**. Material that is 4:3 padded out to 16:9 (or the reverse) carries the bars in the picture itself, where no page background can touch them and where bitrate is spent encoding black. `cropdetect` is sampled at five points across the video and the results are **unioned**, not taken from the last one — a dark scene can otherwise make it mistake picture for border and cut too much. Set `NO_CROP=1` to skip the detection. Cropping is a bonus for quality too: dropping 4:3 pillars from a 16:9 frame removes a quarter of the pixels, so the rest gets about a third more bitrate at the same target size.

Bitrate is `size / duration`, so the length of the video decides everything:

| duration | target 45 MB | quality at 1080p |
|---|---|---|
| 2 min | ~2900 kb/s | very good |
| 5 min | ~1060 kb/s | good |
| 20 min | ~170 kb/s | bad — shorten it or drop the resolution |

The script needs `ffmpeg` and `ffprobe` (Ubuntu: `apt install ffmpeg`, macOS: `brew install ffmpeg`). If you would rather click, **HandBrake** does the same thing — preset *Fast 1080p30*, *Average Bitrate* mode with a value from the table above, and *Web Optimized* checked.

Compressing pays off even when the file would fit: with 100 GB of monthly bandwidth, a 45 MB video covers ~2270 visits, a 244 MB one only ~420. Every one of those megabytes is also downloaded by a viewer on mobile data.

### Git LFS — usually the wrong answer

The workflow checks out with `lfs: true`, so LFS files are resolved before publishing and **do work** (they do not under "Deploy from a branch" — Pages serves the LFS pointer instead of the video). The problem is the free LFS allowance: 1 GB of storage and **1 GB of bandwidth per month**, which a 240 MB video exhausts after four downloads. For this use case LFS almost always loses to compression or to variant C.

## 3. Enabling GitHub Pages

In the repo: **Settings → Pages → Build and deployment → Source: GitHub Actions**.

The workflow (`.github/workflows/pages.yml`) publishes on every push to `main` and on demand from the Actions tab. The site lands at `https://endernoch.github.io/rickthatrolls/`.

## 4. Keeping the video out of the repository

Two things need separating first, because only one of them is achievable:

| | achievable? |
|---|---|
| the video **is not in the repository** and not in git history | **yes** — variants B and C below |
| the video **cannot be downloaded** from the published site | **no** — never on GitHub Pages |

The second one cannot be worked around by any code: if the browser plays the video, it has downloaded it. The `…/video.mp4` address will always return the file, and a Pages site on a Free or Pro account is public **even when the repository is private** (private Pages behind a login is GitHub Enterprise Cloud only). If the video genuinely must not leak, Pages is the wrong place — you need hosting with authorisation: Cloudflare Access, S3 with signed URLs, or a private Vimeo link.

The first one, however, the workflow does for you. The video is added during deployment, so it is absent from the repo's files, from git history, and from the 100 MB limit.

### Variant B — a separate private repository (free)

Private repositories cost nothing, so the video can live in one while the public site repo only reaches for it.

1. Create a private repo, e.g. `rickthatrolls-media`, and push `video.mp4` into it.
2. Generate a token with read access to that repo: **Settings → Developer settings → Personal access tokens → Fine-grained tokens**, `Repository access` = only `rickthatrolls-media`, permission `Contents: Read-only`.
3. In this repo: **Settings → Secrets and variables → Actions**
   - **Variables** tab → `MEDIA_REPO` = `EnderNoch/rickthatrolls-media`
   - **Secrets** tab → `MEDIA_TOKEN` = the generated token

The workflow then checks the private repo out into the working directory and copies the video into `_site/`.

A `401 Bad credentials` in the deploy log means the token string itself is invalid — truncated or with whitespace picked up while copying. A valid token without access to the repo fails differently (`Repository not found`).

### Variant C — a private link

The video lives anywhere a single `curl` can reach (S3 presigned URL, Dropbox with `?dl=1`, your own server). Set `VIDEO_URL` in **Settings → Secrets and variables → Actions → Secrets**. The secret never appears in the logs or on the page.

The format is taken from the extension in the URL — the query string and fragment are stripped, so `…/movie.webm?token=abc` works correctly. A URL **without** an extension (e.g. `…/download?id=99`) is saved as `video.mp4`; if it is really a webm, the browser will skip it because of the mismatched `type`. An unreachable URL fails the deployment instead of quietly publishing an empty page.

### What else limits the reach

Whichever variant you pick, the repo already ships with:

- `robots.txt` with `Disallow: /` and `<meta name="robots" content="noindex, nofollow, noarchive, noimageindex">` — the site stays out of Google,
- `<meta name="referrer" content="no-referrer">` — the address does not leak in the header to sites someone visits next,
- a `<title>` holding a single non-breaking space — the tab shows no text at all. Deleting the tag would be worse: with no title the browser falls back to putting the URL in the tab,
- a transparent 1x1 PNG as `icon` and `apple-touch-icon`, given as a `data:` URI, so the tab carries no icon and the browser never requests `/favicon.ico` and never draws its fallback glyph,
- the Pages artifact contains **only** `index.html`, `robots.txt`, `.nojekyll` and the video — README, LICENSE and the workflow are not served under the site address.

If "hard to find" is enough for you, give the file a random name (e.g. `a7f3c91e4b2d.mp4`, updating `<source src="...">`) and name the subpage the same way — then knowing the repo address gets you nothing. That is security through obscurity, not through permissions.

## 5. Sound and autoplay — the one limit that cannot be worked around

Every browser (Chrome, Safari, Firefox, Edge) **blocks automatic playback with sound** until the user has interacted with the page. That is enforced by the browser engine; it is not something HTML or JS can switch off.

The page handles it like this:

1. It first tries to start with sound. If the visitor has been on this domain before and clicked something, the browser allows it and the video plays with sound from the first frame, with no action needed.
2. If the browser refuses, the video **still starts immediately**, just muted, and a small badge appears at the bottom.
3. **Any** tap, click or keypress turns the sound on at volume 1.0 and the badge disappears. There is no button to hit — the whole screen is live.

### Badge language

The badge is shown in the browser's language. It is picked from `navigator.languages`, matching the full tag first (`pt-BR`), then the bare language (`pt`); Chinese distinguishes Simplified from Traditional script, and legacy codes (`no`, `iw`, `in`, `tl`) are mapped to current ones. Anything not in the table falls back to English.

Around 55 languages are covered; Arabic, Hebrew, Persian and Urdu get `dir="rtl"`. The `HINT` table sits at the top of the script in `index.html`, so fixing a translation is a one-line change. Translations other than English and Polish are best-effort and have not been checked by native speakers.

## 6. Why there is nothing to block

Nothing here is "blocked" — the features simply do not exist. That distinction matters: a block is code that has to be maintained and can always be worked around, while an absent feature has no way to fail.

| what is missing | why |
|---|---|
| control bar, pause, volume slider, seeking | no `controls` attribute — the browser draws no UI at all |
| keyboard response (space, `k`, `m`, `f`, arrows…) | a `<video>` without `controls` **cannot take focus**, so keys never reach it |
| context menu entries "Show controls", "Save video as…", "Loop" | an explicit `contextmenu` preventDefault. `pointer-events: none` is **not** enough — Gecko shows its full video menu anyway |
| Picture-in-Picture, AirPlay, Chromecast | the `disablepictureinpicture` and `disableremoteplayback` attributes |
| page scrolling, pinch-zoom, text selection | `overflow: hidden`, `user-select: none`, `user-scalable=no` |
| the large iOS Safari "play" button | `::-webkit-media-controls-start-playback-button { display: none }` |

**Everything below was measured on Chromium only.** Firefox (Gecko) and Safari (WebKit) could not be run in the environment used.

One Chromium conclusion has since been **disproved on Gecko**: `pointer-events: none` does not stop Firefox from showing its native video context menu. A screenshot from a real Firefox showed the full menu — Pause, Mute, Speed, Loop, Fullscreen, Show controls, Picture-in-Picture, Save video as. So that row is handled by `preventDefault`, and `volumechange` / `ratechange` handlers put the element back when Mute or Speed is used from it anyway.

### Browser controls still work

Everything above reaches the `<video>` element. The controls below belong to the browser, not to the page — they never touch the element, so the page cannot see them, let alone undo them. **They work, and a visitor can use any of them to stop or silence this page:**

| | why the page cannot reach it |
|---|---|
| the speaker icon on the tab, and "Mute tab" in the tab's menu | browser chrome. Muting happens on the tab's audio output, after the element. `muted` and `volume` do not change and no event fires |
| the OS volume mixer, hardware mute | outside the browser entirely |
| closing the tab, the back button, disabling JS, DevTools | the intended ways out |
| Shift + right-click opening the native menu | deliberate Gecko escape hatch; the actions taken from it are undone, the menu itself cannot be suppressed |

The tab audio indicator in particular exists precisely so that a page cannot hide that it is making noise. There is no API to remove it, and playing the audio through Web Audio instead of the element does not avoid it either.

None of this is a gap waiting to be filled. A page runs in a sandboxed renderer with no access to browser chrome, and these particular mechanisms are specified the way they are precisely to stop pages like this one from trapping people. If you need them gone, the answer is a different runtime — a kiosk browser such as Fully Kiosk on a wall panel, or `chrome --kiosk` — not different page code.

**Shift + right-click in Firefox shows the native menu regardless of `preventDefault`**, and from there Mute and Speed do work. That is deliberately not defended against: it belongs in the same category as browser extensions and DevTools, which have been accepted escape hatches from the start. Handlers reverting `volumechange` and `ratechange` existed briefly and were removed — they only ever guarded a path an ordinary visitor never takes, and unused defensive code is the thing this project keeps deleting.

`disablepictureinpicture` is also a Chromium attribute that Gecko ignores, so the Picture-in-Picture entry stays in that menu. Treat the rest of this section as Chromium-verified, not cross-browser.

This was verified against Chromium rather than assumed: a bare `<video>` without `controls` leaves `document.activeElement` on `BODY` even after `.focus()`, and does not react to space, `k`, `p`, `m`, `f`, arrows, `j`/`l` or digits — those shortcuts belong to the YouTube player, not to the browser. Click and double-click do nothing either. The code that used to "block" them was defending against something that does not exist.

Only three things remain in JS, because no amount of absence covers them:

1. **Recovering from a pause.** The page has no way to stop the video, but the browser does: screen sleep, tab switching, muting in the background. That fires a `pause` event and playback has to resume — plus `visibilitychange` and `pageshow` on return, and `stalled`/`error` on a dropped connection.
2. **Media keys, the lock screen, the headphone button.** The only control surface outside the page that cannot be removed. The `mediaSession` handlers remap pause to play.
3. **Autoplay with sound** — described in section 5.

What cannot be stopped, and has no solution in any web technology: closing the tab, the back button, muting the tab from the browser or the OS, disabling JS, DevTools, extensions. Those are the intended way out of the page.

## 7. Looping, scaling and orientation

Looping is done by the native `loop` attribute on `<video>` — not a line of JS. Verified on Chromium over 20 seconds with a three-second clip: **6 full cycles, zero `ended` events, zero `pause` events**, the video never stopped once. The browser simply returns to zero and keeps going.

If you want the seam at the end of the loop to be invisible, force a keyframe every second when encoding (`-g 30 -keyint_min 30` in `ffmpeg`) and make the first and last frames look alike. The looping mechanism itself has nothing to do with it — that is a property of the material.

- `position: fixed` plus `100dvw`/`100dvh` — `dvh` ignores collapsing browser chrome on mobile, so there is no height "jump" while scrolling.
- `object-fit: contain` — **the whole frame stays visible at any window size and aspect ratio**, nothing is cropped. Leftover space is left transparent, so a landscape video on a phone held upright leaves large empty areas. If you prefer the opposite trade-off — a filled window with no bars, but a cropped frame — change `object-fit: contain` to `cover` in `index.html`.
- After `orientationchange` the dimensions are recomputed immediately and again after 100/400/900 ms — iOS Safari only reports the new size once the rotation animation finishes, and without this a blank strip is left behind.
- A `visualViewport` listener also catches the keyboard and system bars appearing.

### Embedding: the bars are transparent

The letterboxed areas have no background of their own, so when the page is put in an iframe — a Home Assistant *Webpage* card with its background hidden, for example — whatever is behind the card shows through instead of a black slab.

Standalone that would be wrong: with no background at all the browser paints its own canvas, which is white in light mode. A `color-scheme: dark` meta does not fix it either, because it forces an opaque dark canvas inside the iframe too, which is exactly what the transparency was for. So the page paints black on `documentElement` only when `window.self === window.top`, and leaves itself transparent when embedded. Cross-origin access to `window.top` can throw, and that case is treated as embedded.

Verified by screenshot in both situations: inside an iframe over a magenta parent the bars are magenta up to the frame edge; opened directly they are black.

## 8. Configuration

At the top of the script in `index.html`:

```js
var VOLUME = 1.0;   // volume once sound is unlocked
```

That is the only setting. Fullscreen and the landscape orientation lock are deliberately **not** configurable — there is no flag to turn them off, only an edit to `index.html`.

### Fullscreen and orientation

Every user gesture requests fullscreen on `documentElement`, and once fullscreen is actually active the page asks for a landscape orientation lock. Both are attempted on *every* gesture, not just the first, so leaving fullscreen and then touching the screen puts you straight back in.

Neither can happen on load: fullscreen requires a user gesture, which is enforced by the browser. The first tap is therefore the one that turns on sound and fullscreen together.

`screen.orientation.lock` only works while fullscreen is active, which is why it is attempted on the `fullscreenchange` event rather than immediately after the request. It works on Android; iOS Safari has no element fullscreen and ignores the orientation lock, so on an iPhone the page simply stays as it is. Leaving fullscreen (Esc, a system gesture) cannot be blocked — the next gesture restores it.

## 9. Testing locally

Do not open `index.html` over `file://` — autoplay and some APIs behave differently there than on Pages. Run a local server:

```bash
python3 -m http.server 8000
```

Then open `http://localhost:8000`.

---

# Polski

[↑ English](#rickthatrolls) · **Polski**

Jednoplikowa strona na GitHub Pages, która po wejściu odtwarza film:

- **bez żadnych kontrolek** — nie dlatego, że są blokowane, tylko dlatego, że ich nie ma: brak atrybutu `controls`, brak fokusu, brak celu dla kursora,
- **non stop w pętli** — jedyne, co jeszcze potrafi zatrzymać film (uśpienie ekranu, klawisz multimedialny), wraca do odtwarzania,
- **na całe okno** — cały kadr widoczny przy każdym rozmiarze okna; obrót telefonu, zmiana rozmiaru okna i chowające się paski przeglądarki są obsłużone,
- **na domyślnej głośności** — z zastrzeżeniem opisanym niżej (autoplay z dźwiękiem),
- **sama strona nie daje jak tego zatrzymać** — ale przeglądarka wokół niej daje i to nie jest zablokowane. Patrz [sterowanie przeglądarki działa](#sterowanie-przegl%C4%85darki-dzia%C5%82a).

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
cp /ścieżka/do/twojego/filmu.mp4 video.mp4
git add -f video.mp4
git commit -m "Add video"
git push
```

`-f` jest potrzebne, bo `.gitignore` blokuje ten plik.

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

Usuwa też **czarne pasy wypalone w klatkach**. Materiał 4:3 dopchany do 16:9 (albo odwrotnie) niesie pasy w samym obrazie — tam nie sięga żadne tło strony, a bitrate idzie na kodowanie czerni. `cropdetect` jest próbkowany w pięciu miejscach filmu, a wyniki brane jako **unia**, nie ostatni pomiar: przy ciemnej scenie potrafi uznać część obrazu za pas i wyciąć za dużo. `NO_CROP=1` pomija wykrywanie. Przycięcie opłaca się też jakościowo: usunięcie pasów 4:3 z kadru 16:9 zabiera jedną czwartą pikseli, więc reszta dostaje przy tym samym celu około jedną trzecią bitrate'u więcej.

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
- `<title>` z samą spacją nierozdzielającą — karta nie pokazuje żadnego napisu. Usunięcie znacznika byłoby gorsze: bez tytułu przeglądarka wpisuje w kartę adres strony,
- przezroczysty PNG 1×1 jako `icon` i `apple-touch-icon`, podany jako `data:` URI, więc karta nie ma ikony, a przeglądarka w ogóle nie pyta o `/favicon.ico` i nie rysuje własnego zastępczego symbolu,
- do artefaktu Pages trafia **wyłącznie** `index.html`, `robots.txt`, `.nojekyll` i film — README, LICENSE i workflow nie są publikowane pod adresem strony.

Jeśli ma to wystarczyć jako „nie do znalezienia", nazwij plik losowym ciągiem (np. `a7f3c91e4b2d.mp4`, podmieniając `<source src="...">`) i tak samo nazwij podstronę — wtedy sam adres repo nic nie daje. To zabezpieczenie przez nieoczywistość, nie przez uprawnienia.

## 5. Dźwięk i autoplay — jedyne ograniczenie, którego nie da się obejść

Wszystkie przeglądarki (Chrome, Safari, Firefox, Edge) **blokują automatyczne odtwarzanie z dźwiękiem**, dopóki użytkownik nie wejdzie w interakcję ze stroną. To zabezpieczenie w silniku przeglądarki, nie coś, co da się wyłączyć z poziomu HTML/JS.

Strona radzi sobie z tym tak:

1. Najpierw próbuje wystartować od razu z dźwiękiem. Jeśli użytkownik był już wcześniej na tej domenie i coś tam klikał, przeglądarka to przepuści i film leci z dźwiękiem od pierwszej klatki — bez żadnej akcji z jego strony.
2. Jeśli przeglądarka odmówi — film **i tak startuje natychmiast**, tylko wyciszony, a na dole pojawia się mała plakietka w języku przeglądarki („Dotknij lub kliknij, aby włączyć dźwięk").
3. **Dowolne** dotknięcie / kliknięcie / naciśnięcie klawisza włącza dźwięk na głośności 1.0 i plakietka znika. Nie trzeba trafiać w przycisk — cały ekran jest aktywny.

### Język plakietki

Plakietka wyświetla się w języku przeglądarki. Język jest wybierany z `navigator.languages`, z dopasowaniem najpierw pełnego tagu (`pt-BR`), potem samego języka (`pt`); chiński rozróżnia pismo uproszczone i tradycyjne, a stare kody (`no`, `iw`, `in`, `tl`) są mapowane na aktualne. Brak wpisu w tabeli = angielski.

Objęte jest ok. 55 języków; arabski, hebrajski, perski i urdu dostają `dir="rtl"`. Tabela `HINT` jest na górze skryptu w `index.html` — poprawka tłumaczenia to zmiana jednej linii. Tłumaczenia poza polskim i angielskim są robione w dobrej wierze, ale nie były sprawdzane przez native speakerów.

## 6. Dlaczego nie ma czego blokować

Nic tu nie jest „zablokowane" — funkcji po prostu nie ma. To ważna różnica: blokada to kod, który trzeba utrzymywać i który zawsze da się obejść, a brak funkcji nie ma jak zawieść.

| czego nie ma | dlaczego |
|---|---|
| pasek sterowania, pauza, suwak głośności, przewijanie | brak atrybutu `controls` — przeglądarka nie rysuje żadnego UI |
| reakcja na klawiaturę (spacja, `k`, `m`, `f`, strzałki…) | `<video>` bez `controls` **nie przyjmuje fokusu**, więc klawisze nigdy do niego nie trafiają |
| menu kontekstowe „Pokaż elementy sterujące", „Zapisz wideo jako…", „Zapętl" | jawne `preventDefault` na `contextmenu`. Samo `pointer-events: none` **nie wystarcza** — Gecko i tak pokazuje pełne menu wideo |
| Picture-in-Picture, AirPlay, Chromecast | atrybuty `disablepictureinpicture` i `disableremoteplayback` |
| przewijanie strony, pinch-zoom, zaznaczanie | `overflow: hidden`, `user-select: none`, `user-scalable=no` |
| duży przycisk „play" iOS Safari | `::-webkit-media-controls-start-playback-button { display: none }` |

**Wszystko poniżej zmierzone jest wyłącznie na Chromium.** Firefoksa (Gecko) ani Safari (WebKit) nie dało się uruchomić w użytym środowisku.

Jeden wniosek z Chromium został już **obalony na Gecko**: `pointer-events: none` nie powstrzymuje Firefoksa przed pokazaniem natywnego menu kontekstowego wideo. Zrzut z prawdziwego Firefoksa pokazał pełne menu — Wstrzymaj, Wycisz, Szybkość, Zapętl, Tryb pełnoekranowy, Wyświetl elementy sterujące, Obraz w obrazie, Zapisz wideo jako. Ten wiersz obsługuje więc `preventDefault`, a handlery `volumechange` i `ratechange` przywracają element, gdy ktoś mimo wszystko użyje stamtąd „Wycisz" albo „Szybkość".

### Sterowanie przeglądarki działa

Wszystko powyżej dotyka elementu `<video>`. Poniższe należy do przeglądarki, nie do strony — nie dotyka elementu wcale, więc strona nie ma jak tego zobaczyć, a tym bardziej cofnąć. **To działa i każdy odwiedzający może tym zatrzymać albo uciszyć tę stronę:**

| | dlaczego strona tego nie dosięga |
|---|---|
| ikonka głośnika na karcie i „Wycisz kartę" z jej menu | interfejs przeglądarki. Wyciszenie działa na wyjściu audio karty, za elementem. `muted` ani `volume` się nie zmieniają i nie leci żadne zdarzenie |
| systemowy mikser głośności, wyciszenie sprzętowe | całkowicie poza przeglądarką |
| zamknięcie karty, przycisk wstecz, wyłączenie JS, DevTools | zamierzone wyjścia |
| Shift + prawy klik otwierający natywne menu | celowa furtka Gecko; akcje z niego są cofane, samego menu ukryć się nie da |

Wskaźnik dźwięku na karcie istnieje dokładnie po to, żeby strona nie mogła ukryć, że hałasuje. Nie ma API, które by go usuwało, a przepuszczenie dźwięku przez Web Audio zamiast przez element też go nie omija.

To nie jest luka czekająca na załatanie. Strona działa w piaskownicy procesu renderującego, bez dostępu do interfejsu przeglądarki, a akurat te mechanizmy są tak zaprojektowane właśnie po to, żeby strony takie jak ta nie mogły uwięzić użytkownika. Jeśli mają zniknąć, odpowiedzią jest inne środowisko uruchomieniowe — przeglądarka kioskowa w rodzaju Fully Kiosk na panelu ściennym albo `chrome --kiosk` — a nie inny kod strony.

**Shift + prawy klik w Firefoksie pokazuje natywne menu niezależnie od `preventDefault`**, a stamtąd „Wycisz" i „Szybkość" faktycznie działają. Celowo nie ma na to obrony: to ta sama kategoria co rozszerzenia przeglądarki i DevTools, przyjęte jako dopuszczalne wyjścia od początku. Handlery cofające `volumechange` i `ratechange` istniały przez chwilę i zostały usunięte — broniły wyłącznie ścieżki, którą zwykły odwiedzający nigdy nie idzie, a nieużywany kod obronny to dokładnie to, co ten projekt konsekwentnie kasuje.

`disablepictureinpicture` to też atrybut Chromium, który Gecko ignoruje, więc pozycja „Obraz w obrazie" w tym menu zostaje. Resztę tej sekcji traktuj jako sprawdzoną na Chromium, nie na wszystkich przeglądarkach.

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
- `object-fit: contain` — **cały kadr jest widoczny przy dowolnym rozmiarze i proporcjach okna**, nic nie jest przycinane. Nadmiar miejsca zostaje przezroczysty, więc przy filmie poziomym na telefonie w pionie puste obszary będą duże. Jeśli wolisz odwrotny kompromis — okno wypełnione bez pasków, ale z przyciętym kadrem — zmień w `index.html` `object-fit: contain` na `cover`.
- Po `orientationchange` wymiary są przeliczane od razu oraz po 100/400/900 ms — iOS Safari raportuje nowy rozmiar dopiero po animacji obrotu i bez tego zostaje pusty pasek.
- Nasłuch na `visualViewport` łapie też pojawienie się klawiatury i pasków systemowych.

### Osadzanie: pasy są przezroczyste

Obszary dopełniające kadr nie mają własnego tła, więc po wstawieniu strony w iframe — na przykład w kartę *Strona WWW* w Home Assistancie z ukrytym tłem — przez pasy widać to, co jest za kartą, zamiast czarnej płachty.

Samodzielnie byłoby to błędem: bez żadnego tła przeglądarka maluje własne płótno, w trybie jasnym białe. Metatag `color-scheme: dark` też tego nie załatwia, bo wymusza nieprzezroczyste ciemne płótno również w iframie, czyli dokładnie to, czemu miała zapobiec przezroczystość. Dlatego strona maluje czerń na `documentElement` tylko wtedy, gdy `window.self === window.top`, a osadzona zostaje przezroczysta. Dostęp do `window.top` między originami potrafi rzucić wyjątkiem — ten przypadek traktujemy jako osadzenie.

Sprawdzone zrzutami w obu sytuacjach: w iframie nad magentowym rodzicem pasy są magentowe aż do krawędzi kadru, a po otwarciu wprost są czarne.

## 8. Konfiguracja

Na górze skryptu w `index.html`:

```js
var VOLUME = 1.0;   // głośność po odblokowaniu dźwięku
```

To jedyne ustawienie. Pełny ekran i blokada orientacji w poziomie **celowo nie są konfigurowalne** — nie ma przełącznika, którym dałoby się je wyłączyć, jest tylko edycja `index.html`.

### Pełny ekran i orientacja

Każdy gest użytkownika żąda pełnego ekranu na `documentElement`, a gdy pełny ekran faktycznie się załączy — strona prosi o blokadę orientacji w poziomie. Oba dzieją się przy *każdym* geście, nie tylko przy pierwszym, więc wyjście z pełnego ekranu i dotknięcie ekranu wraca do niego natychmiast.

Żadne z nich nie może zadziałać przy ładowaniu strony: pełny ekran wymaga gestu użytkownika i wymusza to przeglądarka. Pierwsze dotknięcie włącza więc dźwięk i pełny ekran naraz.

`screen.orientation.lock` działa tylko przy aktywnym pełnym ekranie, dlatego jest wywoływana na zdarzeniu `fullscreenchange`, a nie zaraz po żądaniu. Działa na Androidzie; iOS Safari nie ma pełnego ekranu dla elementu i ignoruje blokadę orientacji, więc na iPhonie strona po prostu zostaje jak jest. Wyjścia z pełnego ekranu (Esc, gest systemowy) nie da się zablokować — przywraca je kolejny gest.

## 9. Test lokalny

Nie otwieraj `index.html` przez `file://` — autoplay i część API zachowują się tam inaczej niż na Pages. Uruchom lokalny serwer:

```bash
python3 -m http.server 8000
```

Potem otwórz `http://localhost:8000`.
