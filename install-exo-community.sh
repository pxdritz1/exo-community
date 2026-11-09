#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "\${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HOME="\${XDG_CONFIG_HOME:-$HOME/.config}"
IGNIS_DIR="$CONFIG_HOME/ignis"
MATUGEN_DIR="$CONFIG_HOME/matugen"
NIRI_CONFIG="$CONFIG_HOME/niri/config.kdl"
STAMP="$(date +%Y%m%d-%H%M%S)"

backup_path() {
    local path="$1"
    if [[ -e "$path" ]]; then
        cp -a -- "$path" "\${path}.backup-\${STAMP}"
        printf '[exo] backup: %s\n' "\${path}.backup-\${STAMP}"
    fi
}

printf '[exo] Installing Exo community configuration\n'

mkdir -p "$IGNIS_DIR" "$MATUGEN_DIR/templates"
if [[ -d "$IGNIS_DIR" ]]; then
    backup_path "$IGNIS_DIR"
fi

python3 - "$ROOT/ignis" "$IGNIS_DIR" <<'PY'
import shutil
import sys
from pathlib import Path

source = Path(sys.argv[1])
target = Path(sys.argv[2])
preserve = {
    Path("user_settings.json"),
    Path("colors.scss"),
    Path("styles/preview-colors.scss"),
}

for item in source.rglob("*"):
    if not item.is_file():
        continue
    relative = item.relative_to(source)
    if "__pycache__" in relative.parts or item.suffix == ".pyc":
        continue
    destination = target / relative
    if relative in preserve and destination.exists():
        continue
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(item, destination)

for relative in preserve:
    destination = target / relative
    bundled = source / relative
    if not destination.exists() and bundled.is_file() and relative != Path("user_settings.json"):
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(bundled, destination)

settings = target / "user_settings.json"
if not settings.exists():
    settings.write_text("{}\n", encoding="utf-8")
PY

TEMPLATE_SOURCE="$ROOT/matugen/templates/colors.scss"
TEMPLATE_TARGET="$MATUGEN_DIR/templates/colors.scss"
if [[ -f "$TEMPLATE_TARGET" ]]; then
    backup_path "$TEMPLATE_TARGET"
fi
cp -f -- "$TEMPLATE_SOURCE" "$TEMPLATE_TARGET"

MATUGEN_CONFIG="$MATUGEN_DIR/config.toml"
if [[ -f "$MATUGEN_CONFIG" ]]; then
    backup_path "$MATUGEN_CONFIG"
fi

python3 - "$MATUGEN_CONFIG" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8") if path.exists() else ""

def update_section(document, header, values):
    pattern = re.compile(
        rf"(?ms)^(\[{re.escape(header)}\]\s*\n)(.*?)(?=^\[|\Z)"
    )
    match = pattern.search(document)
    if match:
        body = match.group(2)
        for key, value in values.items():
            line = re.compile(rf"(?m)^\s*{re.escape(key)}\s*=.*$")
            replacement = f"{key} = {value}"
            if line.search(body):
                body = line.sub(replacement, body, count=1)
            else:
                body = body.rstrip() + "\n" + replacement + "\n"
        return document[:match.start()] + match.group(1) + body + document[match.end():]

    block = f"[{header}]\n" + "".join(
        f"{key} = {value}\n" for key, value in values.items()
    )
    return document.rstrip() + ("\n\n" if document.strip() else "") + block

text = update_section(
    text,
    "config.wallpaper",
    {
        "command": '"awww"',
        "arguments": '["img", "--transition-type", "simple"]',
        "set": "true",
    },
)
text = update_section(
    text,
    "templates.ignis",
    {
        "input_path": '"./templates/colors.scss"',
        "output_path": '"~/.config/ignis/colors.scss"',
    },
)
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(text.rstrip() + "\n", encoding="utf-8")
PY

if [[ -f "$NIRI_CONFIG" ]]; then
    python3 - "$NIRI_CONFIG" <<'PY'
import shutil
import sys
from pathlib import Path

path = Path(sys.argv[1])
lines = path.read_text(encoding="utf-8").splitlines()
required = [
    'spawn-at-startup "ignis" "init"',
    'spawn-at-startup "awww-daemon"',
]
missing = [line for line in required if line not in lines]
if missing:
    backup = path.with_name(path.name + ".backup-exo")
    if not backup.exists():
        shutil.copy2(path, backup)
    if lines and lines[-1].strip():
        lines.append("")
    lines.extend(missing)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"[exo] Added Niri startup entries to {path}")
else:
    print("[exo] Niri startup entries already exist")
PY
else
    printf '[exo] Niri config not found; add these lines manually to %s:\n' "$NIRI_CONFIG"
    printf 'spawn-at-startup "ignis" "init"\nspawn-at-startup "awww-daemon"\n'
fi

mkdir -p "$HOME/.cache"
if ! pgrep -x awww-daemon >/dev/null 2>&1; then
    if command -v awww-daemon >/dev/null 2>&1; then
        nohup awww-daemon >"$HOME/.cache/awww-daemon.log" 2>&1 </dev/null &
        printf '[exo] Started awww-daemon for this session\n'
    else
        printf '[exo] WARNING: awww-daemon is not installed\n'
    fi
else
    printf '[exo] awww-daemon is already running\n'
fi

printf '\n[exo] Configuration installed.\n'
printf '[exo] Your user_settings.json and generated color files were preserved.\n'
printf '[exo] Restart Ignis or log out and back in to load the updated shell.\n'
