#!/bin/bash
# latex-snip.sh — screenshot of an equation in, its LaTeX on the clipboard,
# wrapped as $...$ (inline) or $$...$$ (display), ready for Markdown / LaTeX.
# Uses a local oMLX server (OpenAI-compatible API) running GLM-OCR in formula mode.

# ---- config -----------------------------------------------------------------
OMLX_URL="${OMLX_URL:-http://127.0.0.1:8000/v1/chat/completions}"
MODEL="${MODEL:-GLM-OCR-bf16}"                 # must match an id from /v1/models
API_KEY="${OMLX_API_KEY:-mykey}"               # your oMLX --api-key
CAPTURE="${CAPTURE:-clipboard}"               # only used when no image file is passed in:
                                               #   clipboard = use the image from ⌃⇧⌘4
                                               #   screen    = take the screenshot here (needs Screen Recording)
PROMPT="Formula Recognition:"                  # GLM-OCR's official formula mode (fixed prompt)
DISPLAY_MIN_HEIGHT="${DISPLAY_MIN_HEIGHT:-100}" # snips taller than this (px) become $$...$$
TIDY="${TIDY:-1}"                              # 1 = readable source spacing (never changes rendered math)
PREPROCESS="${PREPROCESS:-1}"                  # 1 = dark-mode invert + upscale small snips + white margin
MIN_HEIGHT="${MIN_HEIGHT:-120}"                # snips shorter than this (px) get upscaled
PAD="${PAD:-24}"                               # white margin (px) added on every side
DEBUG="${DEBUG:-0}"                            # 1 = save what the model sees to ~/Desktop/latexsnip-last.png
# -----------------------------------------------------------------------------

export LANG=en_US.UTF-8   # so pbcopy doesn't mangle unicode when run from Shortcuts

notify() {
  osascript -e 'on run argv' \
            -e 'display notification (item 1 of argv) with title "LaTeX Snip"' \
            -e 'end run' "$1" >/dev/null 2>&1
}

TMP=$(mktemp -d /tmp/latexsnip.XXXXXX)
trap 'rm -rf "$TMP"' EXIT
IMG="$TMP/snip.png"

# 1) Get the image.
if [ -n "${1:-}" ] && [ -s "$1" ]; then
  # Image passed in by the Shortcuts "Take Screenshot" action (Pass Input: as arguments).
  sips -s format png "$1" --out "$IMG" >/dev/null 2>&1 || cp "$1" "$IMG"
  [ -s "$IMG" ] || { notify "Couldn't read the screenshot from Shortcuts."; exit 1; }
elif [ "$CAPTURE" = "screen" ]; then
  # Script takes the screenshot itself (needs Screen Recording permission). Esc = cancel.
  /usr/sbin/screencapture -i -x "$IMG"
  [ -s "$IMG" ] || exit 0
else
  # Use the snip you just took with Control-Shift-Command-4 (macOS's own screenshot tool).
  cat > "$TMP/clip.js" <<'JS'
ObjC.import('AppKit');
function run(argv) {
  const pb = $.NSPasteboard.generalPasteboard;
  for (const [type, ext] of [['public.png', 'png'], ['public.tiff', 'tiff']]) {
    const d = pb.dataForType(type);
    if (d && !d.isNil() && d.length > 0) {
      d.writeToFileAtomically(argv[0] + '.' + ext, true);
      return ext;
    }
  }
  return 'none';
}
JS
  EXT=$(osascript -l JavaScript "$TMP/clip.js" "$TMP/clip" 2>/dev/null)
  case "$EXT" in
    png)  mv "$TMP/clip.png" "$IMG" ;;
    tiff) sips -s format png "$TMP/clip.tiff" --out "$IMG" >/dev/null 2>&1 ;;
    *)    notify "No image on the clipboard — snip with ⌃⇧⌘4 first."; exit 1 ;;
  esac
  [ -s "$IMG" ] || { notify "Couldn't read the clipboard image."; exit 1; }
fi
ORIG_H=$(sips -g pixelHeight "$IMG" | awk '/pixelHeight/{print $2}')

# 2) Make the snip look like what GLM-OCR was trained on: dark ink on white,
#    big enough glyphs, some margin. Every step falls back to the original image on failure.
if [ "$PREPROCESS" = "1" ]; then
  cat > "$TMP/invert.js" <<'JS'
ObjC.import('AppKit');
ObjC.import('CoreImage');
function run(argv) {
  try {
    const path = argv[0];
    const data = $.NSData.dataWithContentsOfFile(path);
    const rep = $.NSBitmapImageRep.imageRepWithData(data);
    const w = rep.pixelsWide, h = rep.pixelsHigh;
    const pts = [[0,0],[w-1,0],[0,h-1],[w-1,h-1],[Math.floor(w/2),0],[Math.floor(w/2),h-1],[0,Math.floor(h/2)],[w-1,Math.floor(h/2)]];
    let sum = 0;
    for (const [x, y] of pts) {
      const c = rep.colorAtXY(x, y).colorUsingColorSpace($.NSColorSpace.deviceRGBColorSpace);
      sum += (c.redComponent + c.greenComponent + c.blueComponent) / 3;
    }
    if (sum / pts.length >= 0.5) return "light";          // already a light background
    const f = $.CIFilter.filterWithName('CIColorInvert');
    f.setValueForKey($.CIImage.imageWithData(data), 'inputImage');
    const outRep = $.NSBitmapImageRep.alloc.initWithCIImage(f.outputImage);
    const pngType = (typeof $.NSBitmapImageFileTypePNG === 'undefined') ? 4 : $.NSBitmapImageFileTypePNG;
    const png = outRep.representationUsingTypeProperties(pngType, $());
    if (!png.writeToFileAtomically(path + ".inv.png", true)) return "error";
    return "inverted";
  } catch (e) { return "error"; }
}
JS
  RES=$(osascript -l JavaScript "$TMP/invert.js" "$IMG" 2>/dev/null)
  [ "$RES" = "inverted" ] && [ -s "$IMG.inv.png" ] && mv "$IMG.inv.png" "$IMG"

  W=$(sips -g pixelWidth  "$IMG" | awk '/pixelWidth/{print $2}')
  H=$(sips -g pixelHeight "$IMG" | awk '/pixelHeight/{print $2}')
  if [ -n "$H" ] && [ "$H" -lt "$MIN_HEIGHT" ]; then          # tiny glyphs -> upscale 2x (3x if very small)
    F=2; [ "$H" -lt $((MIN_HEIGHT / 2)) ] && F=3
    sips --resampleHeight $((H * F)) "$IMG" >/dev/null 2>&1
    W=$(sips -g pixelWidth  "$IMG" | awk '/pixelWidth/{print $2}')
    H=$(sips -g pixelHeight "$IMG" | awk '/pixelHeight/{print $2}')
  fi
  if [ -n "$H" ] && [ -n "$W" ]; then                          # white margin all round
    sips --padToHeightWidth $((H + 2 * PAD)) $((W + 2 * PAD)) --padColor FFFFFF "$IMG" >/dev/null 2>&1
  fi
fi

[ "$DEBUG" = "1" ] && cp "$IMG" "$HOME/Desktop/latexsnip-last.png"

# 3) Build the request (base64 has no characters that need JSON escaping).
B64=$(base64 -i "$IMG" | tr -d '\n')
cat > "$TMP/req.json" <<EOF
{"model":"$MODEL","temperature":0,"max_tokens":2048,"stream":false,
 "messages":[{"role":"user","content":[
   {"type":"image_url","image_url":{"url":"data:image/png;base64,$B64"}},
   {"type":"text","text":"$PROMPT"}]}]}
EOF

# 4) Send to oMLX.
AUTH=()
[ -n "$API_KEY" ] && AUTH=(-H "Authorization: Bearer $API_KEY")
HTTP=$(curl -sS --max-time 120 -o "$TMP/resp.json" -w '%{http_code}' \
        -H "Content-Type: application/json" ${AUTH[@]+"${AUTH[@]}"} \
        --data-binary @"$TMP/req.json" "$OMLX_URL") \
  || { notify "Couldn't reach oMLX at $OMLX_URL — is the server running?"; exit 1; }

if [ "$HTTP" != "200" ]; then
  notify "oMLX error $HTTP: $(head -c 150 "$TMP/resp.json")"
  exit 1
fi

# 5) Parse JSON, strip fences / delimiters the model added, and tidy the source spacing
#    (JavaScript for Automation is built into macOS, so no jq/python needed).
cat > "$TMP/parse.js" <<'JS'
ObjC.import('Foundation');
function tidy(s) {
  const TEXT = new Set(['\\text','\\textrm','\\textbf','\\textit','\\textsf','\\texttt','\\mbox','\\operatorname','\\mathrm']);
  const BIN = new Set(['+','-','=','<','>','\\pm','\\mp','\\times','\\cdot','\\div','\\leq','\\le','\\geq','\\ge',
    '\\neq','\\ne','\\approx','\\equiv','\\sim','\\simeq','\\cong','\\propto','\\to','\\rightarrow','\\leftarrow',
    '\\Rightarrow','\\Leftarrow','\\Leftrightarrow','\\leftrightarrow','\\iff','\\implies','\\mapsto','\\in','\\notin',
    '\\subset','\\subseteq','\\supset','\\supseteq','\\cup','\\cap','\\land','\\lor','\\wedge','\\vee','\\ll','\\gg',
    '\\circ','\\otimes','\\oplus','\\setminus','\\mid','\\perp','\\coloneqq','\\quad','\\qquad','\\forall','\\exists']);
  const OPENERS = new Set(['(','[','{','^','_',',','&','\\\\','\\left','|']);
  // --- tokenize
  const toks = []; let i = 0, ws = false;
  const push = o => { o.sp = ws; ws = false; toks.push(o); };
  while (i < s.length) {
    const c = s[i];
    if (/\s/.test(c)) { ws = true; i++; continue; }
    if (c === '\\') {
      const m = s.slice(i).match(/^\\([a-zA-Z]+|[\s\S])/);
      let cmd = m[0]; i += cmd.length;
      if (TEXT.has(cmd)) {
        let j = i; while (j < s.length && /\s/.test(s[j])) j++;
        if (s[j] === '{') {
          let d = 0, k = j;
          for (; k < s.length; k++) {
            if (s[k] === '\\') { k++; continue; }
            if (s[k] === '{') d++;
            else if (s[k] === '}') { d--; if (d === 0) break; }
          }
          push({ t: cmd + s.slice(j, k + 1), kind: 'atom' }); i = k + 1; continue;
        }
      }
      if (/^\\\s$/.test(cmd)) cmd = '\\ ';
      push({ t: cmd, kind: /^\\[a-zA-Z]/.test(cmd) ? 'cmd' : 'sym' });
      continue;
    }
    push({ t: c, kind: 'ch' }); i++;
  }
  // --- re-emit with consistent spacing
  const stack = []; let out = '', prev = null, pendingScript = false, pendingBegin = false, closed = null;
  const isBin = x => x && BIN.has(x.t);
  for (let n = 0; n < toks.length; n++) {
    const tok = toks[n];
    const compact = stack.some(f => f.script);
    tok.unary = (tok.t === '+' || tok.t === '-') &&
                (!prev || OPENERS.has(prev.t) || isBin(prev) || compact && false);
    if (prev && prev.t === '|' ) {} // keep
    let sep = '';
    if (prev) {
      if (tok.t === '\\\\') sep = ' ';
      else if (prev.t === '\\\\') sep = '\n';
      else if (tok.t === '\\end') sep = '\n';
      else if (closed === 'begin' && tok.t !== '{') sep = '\n';
      else if (prev.t === '&' && isBin(tok)) sep = '';
      else if (tok.t === '&' || prev.t === '&') sep = ' ';
      else if (!compact && isBin(tok) && !tok.unary) sep = ' ';
      else if (!compact && isBin(prev) && !prev.unary) sep = ' ';
      else if (!compact && prev.t === ',') sep = ' ';
      else if (prev.kind === 'cmd' && /^[a-zA-Z]/.test(tok.t)) sep = ' ';
      else if (prev.kind === 'atom' && !compact && (tok.kind !== 'ch' || /^[a-zA-Z0-9]/.test(tok.t))) sep = ' ';
      else if (prev.scriptArg && !compact &&
               (tok.kind === 'cmd' || tok.kind === 'atom' || /^[a-zA-Z0-9]/.test(tok.t))) sep = ' ';
      else if (tok.sp && /^[a-zA-Z0-9]$/.test(prev.t) && /^[a-zA-Z0-9]$/.test(tok.t) &&
               !(/\d/.test(prev.t) && /\d/.test(tok.t))) sep = ' ';
      else if (closed === 'script' && !compact &&
               (tok.kind === 'cmd' || tok.kind === 'atom' || /^[a-zA-Z0-9]/.test(tok.t))) sep = ' ';
    }
    closed = null;
    if (tok.t === '{') {
      stack.push({ script: pendingScript, begin: pendingBegin });
    } else if (tok.t === '}') {
      const f = stack.pop() || {};
      closed = f.script ? 'script' : f.begin ? 'begin' : null;
    }
    tok.scriptArg = !!(prev && (prev.t === '^' || prev.t === '_') && tok.t !== '{');
    pendingScript = (tok.t === '^' || tok.t === '_');
    pendingBegin = (tok.t === '\\begin');
    out += sep + tok.t;
    prev = tok;
  }
  return out.trim();
}
function run(argv) {
  const raw = $.NSString.stringWithContentsOfFileEncodingError(argv[0], $.NSUTF8StringEncoding, null).js;
  const r = JSON.parse(raw);
  let t = (r.choices && r.choices[0].message.content) || "";
  t = t.replace(/<think>[\s\S]*?<\/think>/g, "").trim()
       .replace(/^```[a-zA-Z]*\s*/, "")
       .replace(/\s*```$/, "")
       .trim();
  const wrappers = [/^\$\$([\s\S]*)\$\$$/, /^\\\[([\s\S]*)\\\]$/, /^\\\(([\s\S]*)\\\)$/, /^\$([\s\S]*)\$$/];
  for (const w of wrappers) {
    const m = t.match(w);
    if (m) { t = m[1].trim(); break; }
  }
  if (argv[1] === "1") t = tidy(t);
  return t;
}
JS

LATEX=$(osascript -l JavaScript "$TMP/parse.js" "$TMP/resp.json" "$TIDY")

if [ -z "$LATEX" ]; then
  notify "Model returned nothing — try a tighter crop."
  exit 1
fi

# 6) Wrap as inline $...$ or display $$...$$, then copy.
if printf '%s' "$LATEX" | grep -Eq '\\begin\{|\\\\' \
   || [ "$(printf '%s' "$LATEX" | wc -l)" -gt 0 ] \
   || [ "${#LATEX}" -gt 80 ] \
   || [ "${ORIG_H:-0}" -gt "$DISPLAY_MIN_HEIGHT" ]; then
  # align -> aligned so it renders inside $$ in Markdown (KaTeX/MathJax)
  LATEX=$(printf '%s' "$LATEX" | sed -E 's/\\(begin|end)\{align\*?\}/\\\1{aligned}/g')
  OUT=$(printf '$$\n%s\n$$' "$LATEX")
else
  OUT="\$$LATEX\$"
fi

printf '%s' "$OUT" | pbcopy
notify "Copied: ${OUT:0:90}"
