#!/usr/bin/env bash
# @name: rofi.comic
# @ver: 1.0.0
# @short: Read NetTruyen comics from Rofi
# @usage: hyde-shell rofi.comic [search|read|history|settings|diagnose|feed] [args]
# @global.flag: -h,--help | Show this help message
# @cmd: search
# @cmd.alias: s
# @cmd.desc: Search NetTruyen and read the selection
# @cmd.opt: <keyword> | Search keyword; Rofi asks when omitted
# @cmd: read
# @cmd.desc: Read a story slug or URL, asking for the chapter
# @cmd.opt: <slug-or-url> | NetTruyen story slug or page URL
# @cmd: history
# @cmd.desc: Continue reading from the local history
# @cmd: settings
# @cmd.desc: Change the site base URL, reader mode, or clear the cache
# @cmd: diagnose
# @cmd.desc: Check dependencies, site reachability and configuration

# NetTruyen (nettruyen.info) comic browser for Rofi - the AniSub Comic widget.
#
# Source logic ported from anisub's nettruyen module
# (https://github.com/niyakipham/anisub/blob/main/src/comic/nettruyen.sh):
# chapter lists live inside the story HTML (no API needed), and page images
# follow https://net.imgchapter.store/<slug>/<chap>/page_<i>.jpg - with a
# probe fallback that walks page_<i> until three misses in a row.
#
# Every screen is `rofi -dmenu`; rows are `|`-separated fields shown with
# -display-columns and parsed back field by field. Reading downloads the
# chapter into the cache and opens a local one-page HTML gallery (vertical
# scroll), or hands the images to a custom viewer command when configured.

if [[ ${1:-} != "--rofi-script" && ${1:-} != "script" ]]; then
    if [[ ${HYDE_SHELL_INIT:-0} -ne 1 ]] && command -v hyde-shell >/dev/null 2>&1; then
        eval "$(hyde-shell init)"
    elif declare -F export_hyde_config >/dev/null 2>&1; then
        export_hyde_config
    fi
fi

# Work with or without `hyde-shell init`: fall back to this script's own
# location and plain XDG defaults so it can also run (and be tested) standalone.
_hyde_comic_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${LIB_DIR:-$(dirname -- "$_hyde_comic_dir")}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export HYDE_CONFIG_HOME="${HYDE_CONFIG_HOME:-$XDG_CONFIG_HOME/hyde}"
export HYDE_CACHE_HOME="${HYDE_CACHE_HOME:-$XDG_CACHE_HOME/hyde}"

COMIC_CACHE="${HYDE_CACHE_HOME}/rofi/comic"
COMIC_HISTORY="${COMIC_CACHE}/history"
COMIC_UA="Mozilla/5.0 (X11; Linux x86_64) AniDE/rofi.comic"
COMIC_ROFI_STYLE="${COMIC_ROFI_STYLE:-}"
COMIC_VIEWER="${COMIC_VIEWER:-}"
COMIC_BASE_URL="${COMIC_BASE_URL:-}"
COMIC_IMAGE_HOST="${COMIC_IMAGE_HOST:-}"

# [rofi.comic] keys from ~/.config/hyde/config.toml (same idea as rofi.movie).
_comic_config_get() {
    local key="$1"
    sed -n "/^\[rofi\.comic\]/,/^\[/p" "${HYDE_CONFIG_HOME}/config.toml" 2>/dev/null |
        sed -n "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*\"*\\([^\"]*\\)\"*[[:space:]]*$/\\1/p" |
        head -n 1
}
[[ -z "${COMIC_BASE_URL}" ]] && COMIC_BASE_URL="$(_comic_config_get base_url)"
[[ -z "${COMIC_IMAGE_HOST}" ]] && COMIC_IMAGE_HOST="$(_comic_config_get image_host)"
[[ -z "${COMIC_VIEWER}" ]] && COMIC_VIEWER="$(_comic_config_get viewer)"
COMIC_BASE_URL="${COMIC_BASE_URL:-https://nettruyen.info}"
COMIC_IMAGE_HOST="${COMIC_IMAGE_HOST:-https://net.imgchapter.store}"

mkdir -p "${COMIC_CACHE}" 2>/dev/null || true

comic_rofi() {
    local extra=()
    [[ -n "${COMIC_ROFI_STYLE}" ]] && extra+=(-theme "${COMIC_ROFI_STYLE}")
    rofi -dmenu -i -p "${1:-Comic}" -display-columns 1 "${extra[@]}" "${@:2}"
}

comic_fetch() {
    # comic_fetch <url> -> HTML on stdout; fails on HTTP >= 400
    local url="$1"
    curl -fsSL --max-time 25 -A "${COMIC_UA}" -e "${COMIC_BASE_URL}/" "$url" 2>/dev/null
}

# name|url|slug rows from a story-list page (home / search / genre).
comic_parse_items() {
    COMIC_BASE_URL="${COMIC_BASE_URL}" python3 /dev/fd/3 3<< 'PYEOF'
import html as htmlmod
import os
import re
import sys

base = os.environ.get("COMIC_BASE_URL", "").rstrip("/")
data = sys.stdin.read()
covers = {}
for m in re.finditer(r"(?:images|storage/thumbnails|storage/covers)/([A-Za-z0-9_.\-]+)\.(?:jpe?g|png|webp)", data, re.I):
    covers.setdefault(m.group(1), base + "/" + m.group(0))

def clean(text):
    text = re.sub(r"<[^>]*>", " ", text or "")
    text = htmlmod.unescape(text)
    return re.sub(r"\s+", " ", text).strip()

seen = {}
order = []
for m in re.finditer(r"<a\b([^>]*)>(.*?)</a>", data, re.S | re.I):
    attrs, inner = m.group(1), m.group(2)
    h = re.search(r"href\s*=\s*(?:\"([^\"]*)\"|'([^']*)'|([^\s\">]+))", attrs)
    if not h:
        continue
    href = h.group(1) or h.group(2) or h.group(3) or ""
    r = re.search(r"(?:^|/)(truyen-[A-Za-z0-9_.\-]+)/?(?:[?#].*)?$", href)
    if not r or "/chuong-" in href:
        continue
    route = r.group(1)
    name = ""
    t = re.search(r"title\s*=\s*(?:\"([^\"]*)\"|'([^']*)')", attrs)
    if t:
        name = clean(t.group(1) or t.group(2))
        name = re.sub(r"^Truy(?:en|ện) tranh\s+", "", name, flags=re.I)
    if not name:
        name = clean(inner)
    if not name or len(name) < 2:
        name = route[len("truyen-"):].replace("-", " ").replace("_", " ").title()
    if href.startswith("/"):
        href = base + href
    img = re.search(r"<img\b([^>]*)>", inner, re.I)
    cover = ""
    if img:
        s = re.search(r"data-(?:lazy-)?(?:src|original|echo)\s*=\s*(?:\"([^\"]*)\"|'([^']*)')", img.group(1), re.I)
        if not s:
            s = re.search(r"\ssrc\s*=\s*(?:\"([^\"]*)\"|'([^']*)')", img.group(1), re.I)
        if s:
            cover = (s.group(1) or s.group(2) or "").replace("&amp;", "&")
            if cover.startswith("//"):
                cover = "https:" + cover
            elif cover.startswith("/"):
                cover = base + cover
    if route not in seen:
        seen[route] = True
        order.append((name, href, route, cover or covers.get(route.replace("truyen-", ""), "")))
for name, href, route, cover in order:
    print(f"{name}|{href}|{route}|{cover}")
PYEOF
}

# name|url|number rows from a story page (chapter list, sorted old -> new).
comic_parse_chapters() {
    local route="$1"
    COMIC_BASE_URL="${COMIC_BASE_URL}" NT_ROUTE="${route}" python3 /dev/fd/3 3<< 'PYEOF'
import html as htmlmod
import os
import re
import sys

base = os.environ.get("COMIC_BASE_URL", "").rstrip("/")
route = os.environ.get("NT_ROUTE", "")
data = sys.stdin.read()
rows = []
for m in re.finditer(r"<a\b([^>]*)>(.*?)</a>", data, re.S | re.I):
    attrs, inner = m.group(1), m.group(2)
    h = re.search(r"href\s*=\s*(?:\"([^\"]*)\"|'([^']*)'|([^\s\">]+))", attrs)
    if not h:
        continue
    href = h.group(1) or h.group(2) or h.group(3) or ""
    c = re.search(r"/(truyen-[A-Za-z0-9_.\-]+)/chuong-([0-9][0-9.\-]*)/?(?:[?#].*)?$", href)
    if not c:
        continue
    r, num = c.group(1), c.group(2)
    if route and r != route:
        continue
    if href.startswith("/"):
        href = base + href
    txt = htmlmod.unescape(re.sub(r"<[^>]*>", " ", inner))
    txt = re.sub(r"\s+", " ", txt).strip()
    name = txt if re.match(r"^chapter\b", txt, re.I) and len(txt) <= 40 else f"Chapter {num}"
    rows.append((name, href, num))
rows.sort(key=lambda t: [int(x) if x.isdigit() else x for x in re.split(r"([0-9]+)", t[2])])
for name, href, num in rows:
    print(f"{name}|{href}|chuong-{num}")
PYEOF
}

# image URL rows from a chapter page (page_<i> pattern first, then imgchapter).
comic_parse_images() {
    COMIC_IMAGE_HOST="${COMIC_IMAGE_HOST}" python3 /dev/fd/3 3<< 'PYEOF'
import os
import re
import sys

host = os.environ.get("COMIC_IMAGE_HOST", "https://net.imgchapter.store").rstrip("/")
data = sys.stdin.read()
pages = {}
other = []
for m in re.finditer(r"(?:(?:https?:)?//|/)[^\"'\s<>()]*?/page[_-]?([0-9]+)\.(?:jpe?g|png|webp|avif)", data, re.I):
    url = m.group(0)
    if url.startswith("//"):
        url = "https:" + url
    elif url.startswith("/"):
        url = host + url
    pages.setdefault(int(m.group(1)), url)
for m in re.finditer(r"((?:https?:)?//[^\"'\s<>()]*imgchapter[^\"'\s<>()]*\.(?:jpe?g|png|webp|avif))", data, re.I):
    other.append(m.group(1) if not m.group(1).startswith("//") else "https:" + m.group(1))
if pages:
    for i in sorted(pages):
        print(pages[i])
else:
    seen = set()
    for u in other:
        if u not in seen:
            seen.add(u)
            print(u)
PYEOF
}

# Probe page_<i>.jpg on the image host (anisub fallback): stop after 3 misses.
comic_probe_images() {
    local slug="$1" chap="$2" i code misses=0 found=0
    for i in $(seq 0 299); do
        code=$(curl -s -I --max-time 10 -A "${COMIC_UA}" -o /dev/null -w '%{http_code}' \
            "${COMIC_IMAGE_HOST}/${slug}/${chap}/page_${i}.jpg" 2>/dev/null)
        if [[ "$code" == "200" ]]; then
            printf '%s/%s/%s/page_%s.jpg\n' "${COMIC_IMAGE_HOST}" "${slug}" "${chap}" "${i}"
            misses=0
            found=1
        else
            misses=$((misses + 1))
            [[ $misses -ge 3 ]] && break
        fi
    done
    [[ "$found" == "1" ]]
}

comic_chapter_images() {
    # comic_chapter_images <chapter-url> [slug] [chap]
    local url="$1" html
    html=$(comic_fetch "$url") || html=""
    if [[ -n "$html" ]]; then
        printf '%s' "$html" | comic_parse_images
        return 0
    fi
    if [[ -n "${2:-}" && -n "${3:-}" ]]; then
        comic_probe_images "${2#truyen-}" "$3"
        return $?
    fi
    return 1
}

comic_add_history() {
    # comic_add_history <name> <story-url>
    local tmp
    tmp=$(mktemp "${COMIC_CACHE}/hist.XXXXXX" 2>/dev/null || printf '%s/hist.%s' "${COMIC_CACHE}" "$$")
    { printf '%s|%s\n' "$1" "$2"
      grep -vF "|$2" "${COMIC_HISTORY}" 2>/dev/null | head -n 19
    } > "$tmp" 2>/dev/null && mv -f "$tmp" "${COMIC_HISTORY}" 2>/dev/null
}

comic_open_reader() {
    # comic_open_reader <title> <image-url...>: cache pages, build the gallery
    local title="$1"; shift
    local dir slug tmp html i=0 url file
    slug=$(printf '%s' "$title" | tr -cs 'A-Za-z0-9._-' '-' | sed 's/^-//;s/-$//')
    dir="${COMIC_CACHE}/read-${slug:-chapter}-$$"
    mkdir -p "$dir"
    if [[ -n "${COMIC_VIEWER}" ]]; then
        local files=()
        for url in "$@"; do
            file=$(printf '%s' "$url" | sed 's#[^A-Za-z0-9._-]#_#g')
            curl -fsSL --max-time 30 -A "${COMIC_UA}" -e "${COMIC_BASE_URL}/" -o "${dir}/${file}" "$url" 2>/dev/null && files+=("${dir}/${file}")
        done
        ${COMIC_VIEWER} "${files[@]}" >/dev/null 2>&1 &
        printf '%s\n' "${dir}"
        return 0
    fi
    tmp="${dir}/index.html"
    {
        printf '<!doctype html><meta charset="utf-8"><title>%s</title>\n' "$title"
        printf '<style>body{margin:0;background:#141414;color:#eee;font:14px/1.4 sans-serif}main{max-width:900px;margin:0 auto;padding:12px}img{width:100%%;display:block;margin:0 0 10px;border-radius:6px}h1{font-size:16px}</style>\n'
        printf '<main><h1>%s</h1>\n' "$title"
    } > "$tmp"
    for url in "$@"; do
        i=$((i + 1))
        file=$(printf 'p%03d_%s' "$i" "$(printf '%s' "$url" | sed 's#[^A-Za-z0-9._-]#_#g')")
        if curl -fsSL --max-time 30 -A "${COMIC_UA}" -e "${COMIC_BASE_URL}/" -o "${dir}/${file}" "$url" 2>/dev/null; then
            printf '<img loading="lazy" src="%s" alt="%s">\n' "$file" "$i" >> "$tmp"
        fi
    done
    printf '</main>\n' >> "$tmp"
    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$tmp" >/dev/null 2>&1 &
    else
        printf 'Reader saved at: %s\n' "$tmp"
    fi
    printf '%s\n' "$tmp"
}

comic_pick_story() {
    # stdin: name|url|slug|cover rows -> prints the picked name|url
    local rows picked name url
    rows=$(cat)
    [[ -z "$rows" ]] && return 1
    picked=$(printf '%s\n' "$rows" | comic_rofi "${1:-Story}" -display-columns 1) || return 1
    name="${picked%%|*}"
    url=$(printf '%s' "$picked" | cut -d'|' -f2)
    printf '%s|%s\n' "$name" "$url"
}

comic_search() {
    local kw="${1:-}" rows choice name url route chap_list chap images
    while [[ -z "$kw" ]]; do
        kw=$(rofi -dmenu -p "Search NetTruyen" -l 0 2>/dev/null) || return 1
    done
    rows=$(comic_fetch "${COMIC_BASE_URL}/tim-kiem?keyword=$(printf '%s' "$kw" | sed 's/ /+/g')" | comic_parse_items)
    if [[ -z "$rows" ]]; then
        notify-send "AniSub Comic" "No results for '${kw}' (or the site changed)." 2>/dev/null || true
        return 1
    fi
    choice=$(printf '%s\n' "$rows" | comic_pick_story "Results: ${kw}") || return 1
    name="${choice%%|*}"
    url="${choice##*|}"
    comic_read_url "$name" "$url"
}

comic_read_url() {
    local name="$1" url="$2" route chap_list picked chap_name chap_url chap_num images
    route=$(printf '%s' "$url" | sed -n 's#.*/\(truyen-[A-Za-z0-9_.-]*\)/.*#\1#p')
    [[ -z "$route" ]] && route="${url##*/}"
    chap_list=$(comic_fetch "$url" | comic_parse_chapters "$route")
    if [[ -z "$chap_list" ]]; then
        notify-send "AniSub Comic" "No chapters found for ${name}." 2>/dev/null || true
        return 1
    fi
    picked=$(printf '%s\n' "$chap_list" | comic_rofi "${name} · chapters" -display-columns 1 2>/dev/null ||
        printf '%s\n' "$chap_list" | tac | comic_rofi "${name} · chapters" -display-columns 1) || return 1
    chap_name="${picked%%|*}"
    chap_url=$(printf '%s' "$picked" | cut -d'|' -f2)
    chap_num=$(printf '%s' "$picked" | cut -d'|' -f3 | sed 's/^chuong-//')
    images=$(comic_chapter_images "$chap_url" "$route" "$chap_num")
    if [[ -z "$images" ]]; then
        notify-send "AniSub Comic" "No pages found for ${chap_name}." 2>/dev/null || true
        return 1
    fi
    comic_add_history "$name" "$url"
    # shellcheck disable=SC2046
    comic_open_reader "${name} · ${chap_name}" $(printf '%s\n' "$images")
}

comic_read() {
    local target="${1:-}" name url
    [[ -z "$target" ]] && target=$(rofi -dmenu -p "Story slug or URL" -l 0 2>/dev/null) || true
    [[ -z "$target" ]] && return 1
    case "$target" in
        http://*|https://*) url="$target" ;;
        truyen-*) url="${COMIC_BASE_URL}/${target}" ;;
        *) url="${COMIC_BASE_URL}/truyen-${target}" ;;
    esac
    name="${url##*/}"
    comic_read_url "$name" "$url"
}

comic_history() {
    local picked name url
    [[ -s "${COMIC_HISTORY}" ]] || { notify-send "AniSub Comic" "History is empty." 2>/dev/null || true; return 1; }
    picked=$(comic_rofi "History" < "${COMIC_HISTORY}") || return 1
    name="${picked%%|*}"
    url="${picked##*|}"
    comic_read_url "$name" "$url"
}

comic_settings() {
    local picked key value
    picked=$(printf '%s\n' "Base URL: ${COMIC_BASE_URL}" "Image host: ${COMIC_IMAGE_HOST}" "Reader: ${COMIC_VIEWER:-HTML gallery (xdg-open)}" "Clear cache and history" |
        comic_rofi "Comic settings") || return 1
    case "$picked" in
        "Clear cache"*)
            rm -rf "${COMIC_CACHE}" 2>/dev/null || true
            mkdir -p "${COMIC_CACHE}" 2>/dev/null || true
            notify-send "AniSub Comic" "Cache and history cleared." 2>/dev/null || true
            ;;
        "Reader:"*)
            value=$(rofi -dmenu -p "Viewer command (empty = HTML gallery)" -l 0 2>/dev/null) || return 0
            key="viewer"
            ;;
        "Base URL:"*)
            value=$(rofi -dmenu -p "NetTruyen base URL" -l 0 2>/dev/null) || return 0
            key="base_url"
            ;;
        "Image host:"*)
            value=$(rofi -dmenu -p "Chapter image host" -l 0 2>/dev/null) || return 0
            key="image_host"
            ;;
        *) return 0 ;;
    esac
    mkdir -p "${HYDE_CONFIG_HOME}" 2>/dev/null || true
    if grep -q '^\[rofi\.comic\]' "${HYDE_CONFIG_HOME}/config.toml" 2>/dev/null; then
        sed -i "/^\[rofi\.comic\]/,/^\[/ s|^[[:space:]]*${key}[[:space:]]*=.*|${key} = \"${value}\"|" "${HYDE_CONFIG_HOME}/config.toml"
    else
        printf '\n[rofi.comic]\n%s = "%s"\n' "$key" "$value" >> "${HYDE_CONFIG_HOME}/config.toml"
    fi
    notify-send "AniSub Comic" "Saved ${key}." 2>/dev/null || true
}

comic_diagnose() {
    local out dep
    out="AniSub Comic (rofi.comic) diagnostics\n"
    for dep in curl python3 rofi xdg-open; do
        if command -v "$dep" >/dev/null 2>&1; then
            out="${out}✓ ${dep}\n"
        else
            out="${out}✗ ${dep} missing\n"
        fi
    done
    out="${out}base: ${COMIC_BASE_URL}\nimage host: ${COMIC_IMAGE_HOST}\n"
    out="${out}HTTP: $(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "${COMIC_BASE_URL}/" 2>/dev/null || printf '000')\n"
    printf '%b' "$out"
    command -v notify-send >/dev/null 2>&1 && notify-send "AniSub Comic" "$(printf '%b' "$out")" 2>/dev/null || true
}

case "${1:-search}" in
    search|s) comic_search "${2:-}" ;;
    read) comic_read "${2:-}" ;;
    history) comic_history ;;
    settings) comic_settings ;;
    feed)
        # Machine-readable wallpaper-widget feed: name|url|slug|cover
        comic_fetch "${COMIC_BASE_URL}/" | comic_parse_items | head -n "${COMIC_FEED_LIMIT:-6}"
        ;;
    feed-search)
        # Widget search (never opens rofi): same name|url|slug|cover rows for a keyword
        kw="${2:-}"
        [[ ${#kw} -lt 2 ]] && exit 0
        q=$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote_plus(sys.argv[1]))' "$kw") || exit 1
        comic_fetch "${COMIC_BASE_URL}/tim-kiem?keyword=${q}" | comic_parse_items | head -n "${COMIC_FEED_LIMIT:-6}"
        ;;
    diagnose) comic_diagnose ;;
    -h|--help|help) grep -E '^# @(usage|cmd)' "$0" | sed 's/^# @/  /' ;;
    *) comic_search "${1:-}" ;;
esac
