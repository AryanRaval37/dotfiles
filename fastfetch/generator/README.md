# Fastfetch mountains

Turns photos of mountains into coloured text art for the fastfetch logo, with a caption like
`MATTERHORN ─ ▲ 4,478 m · 14,692 ft`. fastfetch then shows a random one on every new shell:

```jsonc
"logo": { "type": "file-raw", "source": "~/.config/fastfetch/mountains/*.txt" }
```

Needs `curl`, `jq` and `chafa`; `imagemagick` (better contrast, `--crop`) and `fzf` (for `review.sh`) are optional.

## mountain2ascii.sh: make one logo

Give it a Wikipedia title. It finds a landscape photo (Wikipedia's lead image, or a horizontal one
from Wikimedia Commons), reads the elevation from Wikidata, renders the photo with chafa and saves
`<name>.txt`. If the title isn't an exact page it shows the closest matches and asks which one
to use (`0` keeps the name you typed).

```bash
./mountain2ascii.sh "Lhotse"
./mountain2ascii.sh "Kangchenjunga" --pick 3                 # 3rd horizontal Commons photo instead
./mountain2ascii.sh "Matterhorn" --image "https://commons.wikimedia.org/wiki/File:X.jpg"
./mountain2ascii.sh "Rathong" --image ~/Pictures/rathong.jpg --elev 6000   # own photo + height
./mountain2ascii.sh "K2" --out ./test-out                    # try it without touching the live folder
./mountain2ascii.sh --help
```

| Option | |
|---|---|
| `--image URL\|PATH` | use this photo (Commons page, upload.wikimedia.org link, any URL, or a local file) |
| `--pick N` | skip the lead photo and use the Nth horizontal Commons search result |
| `--crop GRAV:WxH` | crop first, e.g. `north:70%x60%` (needs ImageMagick) |
| `--style STYLE` | `sextant` (default, sharpest), `blocks`, `braille`, `ascii`, `color-ascii` |
| `--size WxH` | max size in terminal cells (default `70x45`) |
| `--elev METRES` | override the elevation |
| `--out DIR` | where to save (default `~/.config/fastfetch/mountains`) |
| `--keep` | keep the downloaded photo and print where it is |

Only horizontal photos are used (1.2–2.4× wider than tall).

## build-all.sh: make logos for a whole list

Runs `mountain2ascii.sh` for every line of `mountains.list` (94 mountains). Any extra options
are passed through to every run. It never stops to ask, and takes the first match instead.

```bash
./build-all.sh                                   # everything in mountains.list → live folder
./build-all.sh --out ./test-out                  # build into a test folder instead
./build-all.sh mountains.list --style braille --out ./braille-test
./build-all.sh my-other.list                     # any list file(s) in the same format
```

List format, one mountain per line (`#` starts a comment, blank fields are fine):

```
Wikipedia title   | image URL or path | crop           | elevation m
Kedarnath         |                   |                | 6940
Matterhorn        |                   | north:70%x60%  |
```

Failures are listed at the end and written to `build-errors.log`.

## review.sh: look through the art

Only "delete" changes anything, and it moves files to the macOS Trash, never deletes them.

```bash
./review.sh              # fzf picker with live preview · enter: run fastfetch with it · ctrl-d: Trash it
./review.sh all          # page through every file · enter: next · d: Trash · q: quit
./review.sh k2           # print one (file name without .txt)
./review.sh ff k2        # run fastfetch with that one as the logo
./review.sh ./test-out   # any of the above for another folder, e.g. ./review.sh ./test-out all
```
