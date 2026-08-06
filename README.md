# rickthatrolls

**English** · [Polski](README.pl.md)

A single-file GitHub Pages site that plays a video the moment you land on it:

- **no controls at all** — not because they are blocked, but because they do not exist: no `controls` attribute, no focus, no hit target for the cursor,
- **looping forever** — the only things that can still stop it (screen sleep, a media key) are turned back into playback,
- **fills the window** — the whole frame stays visible at any window size; phone rotation, window resizing and collapsing browser chrome are handled,
- **at full volume** — with the one caveat described below (autoplay with sound),
- the only way out is closing the tab or navigating back.

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
- an empty `<title>` — the tab says nothing about the content,
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
| context menu entries "Show controls", "Save video as…", "Loop" | `pointer-events: none` — the video is not a hit target, right-click lands on `<body>` |
| Picture-in-Picture, AirPlay, Chromecast | the `disablepictureinpicture` and `disableremoteplayback` attributes |
| page scrolling, pinch-zoom, text selection | `overflow: hidden`, `user-select: none`, `user-scalable=no` |
| the large iOS Safari "play" button | `::-webkit-media-controls-start-playback-button { display: none }` |

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
- `object-fit: contain` — **the whole frame stays visible at any window size and aspect ratio**, nothing is cropped. Leftover space is filled with black, so a landscape video on a phone held upright leaves large black areas. If you prefer the opposite trade-off — a filled window with no bars, but a cropped frame — change `object-fit: contain` to `cover` in `index.html`.
- After `orientationchange` the dimensions are recomputed immediately and again after 100/400/900 ms — iOS Safari only reports the new size once the rotation animation finishes, and without this a blank strip is left behind.
- A `visualViewport` listener also catches the keyboard and system bars appearing.

## 8. Configuration

At the top of the script in `index.html`:

```js
var VOLUME          = 1.0;   // volume once sound is unlocked
var AUTO_FULLSCREEN = false; // true = the first tap enters fullscreen
```

`AUTO_FULLSCREEN = true` additionally tries to lock the orientation to landscape (`screen.orientation.lock`) — works on Android, iOS ignores it.

## 9. Testing locally

Do not open `index.html` over `file://` — autoplay and some APIs behave differently there than on Pages. Run a local server:

```bash
python3 -m http.server 8000
```

Then open `http://localhost:8000`.
