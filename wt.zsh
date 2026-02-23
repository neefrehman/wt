# ---------------------------------------------------------------------------
# Patterns — edit these to add support for new ecosystems, tools, or editors
# ---------------------------------------------------------------------------

# Lockfile → install command mapping. Order controls detection priority.
_WT_LOCKFILE_NAMES=(pnpm-lock.yaml yarn.lock bun.lock bun.lockb package-lock.json uv.lock poetry.lock Pipfile.lock Gemfile.lock go.sum Cargo.lock composer.lock)
typeset -A _WT_LOCKFILE_COMMANDS
_WT_LOCKFILE_COMMANDS=(
    pnpm-lock.yaml    "pnpm install"
    yarn.lock         "yarn install"
    bun.lock          "bun install"
    bun.lockb         "bun install"
    package-lock.json "npm install"
    uv.lock           "uv sync"
    poetry.lock       "poetry install"
    Pipfile.lock      "pipenv install"
    Gemfile.lock      "bundle install"
    go.sum            "go mod download"
    Cargo.lock        "cargo fetch"
    composer.lock     "composer install"
)

# Dependency directories (excluded from sync — installed separately)
_WT_DEP_DIRS=(node_modules .venv venv __pycache__ .tox .eggs .terraform .terragrunt-cache vendor)

# Config files/directories to sync
_WT_CONFIG_DIRS=(.claude .vscode .cursor .windsurf .idea)
_WT_CONFIG_FILES=(lefthook-local.yml .tool-versions .nvmrc .node-version .python-version .ruby-version .go-version)

# Build artifact directories
_WT_BUILD_DIRS=(dist build .next out target)

# Tool cache directories (dot-prefixed)
_WT_CACHE_DIRS=(.mypy_cache .ruff_cache .pytest_cache .import_linter_cache .cache)

# Noise files — excluded from sync operations and gitignored file listings
_WT_NOISE_FILES=(.DS_Store .tsbuildinfo CACHEDIR.TAG)
_WT_NOISE_PATTERN='(\.DS_Store|\.tsbuildinfo|next-env\.d\.ts|CACHEDIR\.TAG|\.gitignore|chromium-pack\.tar)$'

# Theme rotation pool
_WT_THEMES=("Solarized Dark" "Abyss" "Kimbie Dark" "Quiet Light" "Monokai" "Tomorrow Night Blue" "Red" "Solarized Light" "Monokai Dimmed")

# ---------------------------------------------------------------------------
# Sync categories — derived from patterns above
# ---------------------------------------------------------------------------

# Build regex patterns from the arrays above (lazy-initialized to avoid sed at source time)
_WT_SYNC_CATEGORY_KEYS=(deps dotenv config build cache)
typeset -A _WT_SYNC_CATEGORY_LABELS _WT_SYNC_CATEGORY_PATTERNS _WT_SYNC_CATEGORY_DEFAULTS
typeset -g _wt_patterns_built=false
_WT_SYNC_CATEGORY_LABELS=(
    deps    "Installed dependencies"
    dotenv  "Dotenv files"
    config  "Local config (e.g. .claude/*, .vscode/*, lefthook-local.yml)"
    build   "Build artifacts (e.g. .next, out)"
    cache   "Tool caches (e.g. ruff_cache, import_linter_cache)"
)
_wt_build_patterns() {
    $_wt_patterns_built && return
    _wt_patterns_built=true
    # Escape dots and join with | using zsh parameter expansion
    local -a _escaped
    _escaped=("${_WT_DEP_DIRS[@]//./\\.}")
    _WT_SYNC_CATEGORY_PATTERNS[deps]="(^|/)(${(j:|:)_escaped})(/|$)"
    _WT_SYNC_CATEGORY_PATTERNS[dotenv]='(^|/)\.env($|[./])'
    _escaped=("${_WT_CONFIG_DIRS[@]//./\\.}")
    local -a _escaped2=("${_WT_CONFIG_FILES[@]//./\\.}")
    _WT_SYNC_CATEGORY_PATTERNS[config]="(^|/)(${(j:|:)_escaped})(/|$)|(^|/)(${(j:|:)_escaped2})$"
    _escaped=("${_WT_BUILD_DIRS[@]//./\\.}")
    _WT_SYNC_CATEGORY_PATTERNS[build]="(^|/)(${(j:|:)_escaped})(/|$)"
    _escaped=("${_WT_CACHE_DIRS[@]//./\\.}")
    _WT_SYNC_CATEGORY_PATTERNS[cache]="(^|/)(${(j:|:)_escaped})(/|$)"
}
# "on" = synced by default, "off" = not synced, "fixed" = always excluded (not toggleable)
_WT_SYNC_CATEGORY_DEFAULTS=(
    deps fixed  dotenv on  config on  build off  cache off
)

# Find *.code-workspace files up to 3 levels deep, relative to <root>.
# Excludes node_modules, .git, and other noise directories.
_wt_find_workspace_files() {
    local root="$1"
    [[ -d "$root" ]] || return 1
    find "$root" -maxdepth 3 \
        -name '*.code-workspace' \
        -not -path '*/node_modules/*' \
        -not -path '*/.git/*' \
        -not -path '*/dist/*' \
        -not -path '*/.next/*' \
        2>/dev/null \
        | while IFS= read -r f; do
            echo "${f#$root/}"
        done
}

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------

_WT_C_RESET=$'\033[0m'
_WT_C_BOLD=$'\033[1m'
_WT_C_DIM=$'\033[2m'
_WT_C_RED=$'\033[31m'
_WT_C_GREEN=$'\033[32m'
_WT_C_YELLOW=$'\033[33m'
_WT_C_MAGENTA=$'\033[35m'
_WT_C_CYAN=$'\033[36m'
_WT_C_BOLD_YELLOW=$'\033[1;33m'

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------

_WT_PALETTES=(
    "#06b6d4,#818cf8,#34d399"
    "#f472b6,#c084fc,#818cf8"
    "#34d399,#2dd4bf,#60a5fa"
    "#fb923c,#f472b6,#c084fc"
    "#a78bfa,#60a5fa,#34d399"
    "#fbbf24,#fb923c,#f472b6"
    "#4ade80,#22d3ee,#a78bfa"
    "#f87171,#fbbf24,#34d399"
)

_wt_banner() {
    local palette="${_WT_PALETTES[$(( RANDOM % ${#_WT_PALETTES} + 1 ))]}"

    python3 - "$palette" <<'PYEOF'
import sys, random

def hex_to_ansi(h):
    h = h.lstrip("#")
    return f"\033[38;2;{int(h[0:2],16)};{int(h[2:4],16)};{int(h[4:6],16)}m"

def hex_to_rgb(h):
    h = h.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)

palette = sys.argv[1].split(",")
if len(palette) < 3:
    r1, r2 = hex_to_rgb(palette[0]), hex_to_rgb(palette[1])
    palette.append("#%02x%02x%02x" % tuple((a + b) // 2 for a, b in zip(r1, r2)))

c = [hex_to_ansi(x) for x in palette]
R = "\033[0m"

art = r"""
             .:;¦\¯`'¯`'¯\ :;/¯`'¯`;'/¦¦¯`'¯`'¯¦¦\¯`'¯`'¯\__
;/¯`'¯`'¯/¦.:;'¦;¦ -   --:;¦'/___:;/:;/  -  -.:;'/¦;¦__''__''¦
¦   -  .:;¦;'¦/¯\/    -.:;'/¦'¦¦`'¯`'`¦/     - ;/;'¦;¦.  '¯`¦¦
¦\   -  -:;\/;/\_____/:;¦¦L,  .:\__'___\ -:;'¦.:;/;¦L,__.:;'¦
¦:;\_____/:;¦¦¯`¯`'¦¦:;'¦  ¯¯¯;¦.     ;/    ¯¯¯¯¯
¦:;¦¦¯`'¯`'¦¦.:;;      ;¦;'/'     .:;¦;¦¦¯`'¯`'¦¦
;\;¦;      ;¦;/\L_ .:;'¦/'      .:;¦;¦;     :;¦
:;'¦L_ .:;'¦/'       ¯           .:;\¦L_  .:;¦
         ¯¯               '               ¯¯
""".strip("\n").split("\n")

split = 30
soft = set(".:;'-`")

print()
for line in art:
    out = "  "
    prev = None
    for i, ch in enumerate(line):
        if ch == " ":
            out += ch
            continue
        pri = c[0] if i < split else c[1]
        alt = c[1] if i < split else c[0]
        r = random.random()
        if ch in soft:
            color = c[2] if r < 0.18 else (alt if r < 0.28 else pri)
        else:
            color = c[2] if r < 0.07 else (alt if r < 0.10 else pri)
        if color != prev:
            out += color
            prev = color
        out += ch
    out += R
    print(out)
PYEOF
}

# ---------------------------------------------------------------------------
# In-place status line helpers
# ---------------------------------------------------------------------------

# Print a spinning status line. Returns the spinner PID via _wt_spinner_pid.
# Usage: _wt_spin "Syncing files"; ...; _wt_spin_done "Files synced"
typeset -g _wt_spinner_pid=0

_wt_spin() {
    local msg="$1"
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    printf "  %s ${_WT_C_DIM}%s${_WT_C_RESET}" "${frames[1]}" "$msg"
    {
        local i=1
        while true; do
            sleep 0.08
            i=$(( i % ${#frames} + 1 ))
            printf "\r  %s ${_WT_C_DIM}%s${_WT_C_RESET}" "${frames[$i]}" "$msg"
        done
    } &
    _wt_spinner_pid=$!
}

_wt_spin_done() {
    local msg="$1"
    if (( _wt_spinner_pid > 0 )); then
        kill "$_wt_spinner_pid" 2>/dev/null
        wait "$_wt_spinner_pid" 2>/dev/null
        _wt_spinner_pid=0
    fi
    _wt_linef ok "$msg"
}

_wt_spin_skip() {
    local msg="$1"
    if (( _wt_spinner_pid > 0 )); then
        kill "$_wt_spinner_pid" 2>/dev/null
        wait "$_wt_spinner_pid" 2>/dev/null
        _wt_spinner_pid=0
    fi
    _wt_linef skip "$msg"
}

# Print a bold heading.
# Usage: _wt_heading "Creating worktree ${_WT_C_YELLOW}$name"
_wt_heading() {
    echo "${_WT_C_BOLD}${1}${_WT_C_RESET}"
}

# Print a status line with icon.
# Usage: _wt_line ok|warn|err|skip "message"
#   ok   → green ✓
#   warn → yellow ⚠
#   err  → red ✗
#   skip → dim –
_wt_line() {
    local kind="$1" msg="$2"
    case "$kind" in
        ok)   echo "  ${_WT_C_GREEN}✓${_WT_C_RESET} ${msg}" ;;
        warn) echo "  ${_WT_C_YELLOW}⚠${_WT_C_RESET} ${msg}" ;;
        err)  echo "  ${_WT_C_RED}✗${_WT_C_RESET} ${msg}" >&2 ;;
        skip) echo "  ${_WT_C_DIM}– ${msg}${_WT_C_RESET}" ;;
    esac
}

# Printf variant of _wt_line for spinner/terminal-control contexts.
# Prepends \r, appends \033[K\n — used inside _wt_render_init_lines and delete spinners.
_wt_linef() {
    local kind="$1" msg="$2"
    case "$kind" in
        ok)   printf "\r  ${_WT_C_GREEN}✓${_WT_C_RESET} %s\033[K\n" "$msg" ;;
        warn) printf "\r  ${_WT_C_YELLOW}⚠${_WT_C_RESET} %s\033[K\n" "$msg" ;;
        err)  printf "\r  ${_WT_C_RED}✗${_WT_C_RESET} %s\033[K\n" "$msg" ;;
        skip) printf "\r  ${_WT_C_DIM}– %s${_WT_C_RESET}\033[K\n" "$msg" ;;
    esac
}

# ---------------------------------------------------------------------------
# Interactive picker
# ---------------------------------------------------------------------------

# Arrow-key and letter-shortcut picker.
# Args: key1 label1 key2 label2 ...
# Returns: 0-based index of selection via exit code.
typeset -g _wt_pick_init_sel=0
typeset -g _wt_last_pick_lines=0

_wt_pick() {
    local -a keys labels
    while (( $# >= 2 )); do
        keys+=("$1")
        labels+=("$2")
        shift 2
    done
    local count=${#labels}
    local sel=1
    if (( _wt_pick_init_sel > 0 && _wt_pick_init_sel <= count )); then
        sel=$_wt_pick_init_sel
    fi
    _wt_pick_init_sel=0

    _wt_pick_render() {
        local i
        for (( i = 1; i <= count; i++ )); do
            if (( i == sel )); then
                printf "  ${_WT_C_CYAN}${_WT_C_BOLD}› %s${_WT_C_RESET}  ${_WT_C_DIM}(%s)${_WT_C_RESET}\n" \
                    "${labels[$i]}" "${keys[$i]}"
            else
                printf "  ${_WT_C_DIM}  %s${_WT_C_RESET}  ${_WT_C_DIM}(%s)${_WT_C_RESET}\n" \
                    "${labels[$i]}" "${keys[$i]}"
            fi
        done
    }

    _wt_pick_render
    printf '\033[?25l' # hide cursor
    trap 'printf "\033[?25h"' INT TERM

    local key seq i
    while true; do
        read -rsk 1 key
        case "$key" in
            $'\033')
                if read -rsk 1 -t 0.05 seq 2>/dev/null && [[ "$seq" == "[" ]]; then
                    read -rsk 1 -t 0.05 key 2>/dev/null
                    case "$key" in
                        A) (( sel <= 1 )) && sel=$count || (( sel-- )) ;;
                        B) (( sel >= count )) && sel=1 || (( sel++ )) ;;
                    esac
                else
                    printf '\033[?25h'
                    trap - INT TERM
                    return 255
                fi
                ;;
            $'\n'|$'\r'|'')
                break
                ;;
            *)
                for (( i = 1; i <= count; i++ )); do
                    if [[ "${(L)key}" == "${(L)keys[$i]}" ]]; then
                        sel=$i
                        break 2
                    fi
                done
                continue
                ;;
        esac
        printf "\033[${count}A"
        _wt_pick_render
    done

    printf '\033[?25h' # show cursor
    trap - INT TERM
    return $(( sel - 1 ))
}

# Arrow-key multi-select picker.
# Args: label1 label2 ...
# Sets global array _wt_multi_pick_result with selected labels.
# Optional: set _wt_mp_init_selected=(1 0 1 ...) before calling to override
# per-item defaults for toggleable items (indexed from 1, after disabled prefix).
typeset -ga _wt_multi_pick_result
typeset -ga _wt_mp_init_selected

_wt_multi_pick() {
    _wt_multi_pick_result=()
    local init_val=0 disabled_prefix=0
    while [[ "${1:-}" == --* ]]; do
        case "$1" in
            --all) init_val=1; shift ;;
            --disabled-prefix) disabled_prefix=$2; shift 2 ;;
            *) break ;;
        esac
    done
    local -a items=("$@")
    local count=${#items}
    local sel=$(( disabled_prefix + 1 ))
    local -a selected
    for (( i = 1; i <= disabled_prefix; i++ )); do selected[$i]=-1; done
    if (( ${#_wt_mp_init_selected} > 0 )); then
        for (( i = disabled_prefix + 1; i <= count; i++ )); do
            selected[$i]=${_wt_mp_init_selected[$(( i - disabled_prefix ))]:-$init_val}
        done
        _wt_mp_init_selected=()
    else
        for (( i = disabled_prefix + 1; i <= count; i++ )); do selected[$i]=$init_val; done
    fi

    # Strip ANSI codes and truncate to fit terminal width
    _wt_mp_truncate() {
        local text="$1" max_visible="$2"
        # Get visible length by stripping ANSI escape codes
        local stripped="${text//$'\033'\[*([0-9;])m/}"
        if (( ${#stripped} <= max_visible )); then
            printf '%s' "$text"
            return
        fi
        # Truncate: walk through chars, track visible length
        local out="" visible=0 in_esc=false
        local ch
        for (( j = 1; j <= ${#text}; j++ )); do
            ch="${text[$j]}"
            if $in_esc; then
                out+="$ch"
                [[ "$ch" == m ]] && in_esc=false
            elif [[ "$ch" == $'\033' ]]; then
                out+="$ch"
                in_esc=true
            else
                (( visible >= max_visible - 1 )) && { out+="…"; break; }
                out+="$ch"
                (( visible++ ))
            fi
        done
        printf '%s' "$out"
    }

    _wt_mp_render() {
        local i cols=${COLUMNS:-80}
        local max_label=$(( cols - 8 ))  # account for prefix "  › ✓ "
        local marker label
        for (( i = 1; i <= count; i++ )); do
            label=$(_wt_mp_truncate "${items[$i]}" "$max_label")
            if (( selected[$i] == -1 )); then
                # Disabled item — always ✗, never highlighted
                printf "    ${_WT_C_DIM}✗ %s${_WT_C_RESET}\n" "$label"
            elif (( i == sel )); then
                marker="${_WT_C_DIM}○${_WT_C_RESET}"
                (( selected[$i] )) && marker="${_WT_C_GREEN}✓${_WT_C_RESET}"
                printf "  ${_WT_C_CYAN}${_WT_C_BOLD}›${_WT_C_RESET} %s ${_WT_C_CYAN}${_WT_C_BOLD}%s${_WT_C_RESET}\n" "$marker" "$label"
            else
                marker="${_WT_C_DIM}○${_WT_C_RESET}"
                (( selected[$i] )) && marker="${_WT_C_GREEN}✓${_WT_C_RESET}"
                printf "    %s ${_WT_C_DIM}%s${_WT_C_RESET}\n" "$marker" "$label"
            fi
        done
        echo ""
        printf "  ${_WT_C_DIM}↑↓ navigate · space select · a all · enter confirm · esc cancel${_WT_C_RESET}\n"
    }

    _wt_mp_render
    printf '\033[?25l'
    trap 'printf "\033[?25h"' INT TERM

    local key seq any_off new_val _escaped=0
    local total_lines=$(( count + 2 ))
    local _first=$(( disabled_prefix + 1 ))

    while true; do
        read -rsk 1 key
        case "$key" in
            $'\033')
                if read -rsk 1 -t 0.05 seq 2>/dev/null && [[ "$seq" == "[" ]]; then
                    read -rsk 1 -t 0.05 key 2>/dev/null
                    case "$key" in
                        A) (( sel <= _first )) && sel=$count || (( sel-- )) ;;
                        B) (( sel >= count )) && sel=$_first || (( sel++ )) ;;
                    esac
                else
                    # Timeout — bare escape, cancel
                    _escaped=1
                    break
                fi
                ;;
            ' ')
                (( selected[$sel] != -1 )) && (( selected[$sel] = !selected[$sel] ))
                ;;
            a)
                any_off=0
                for (( i = disabled_prefix + 1; i <= count; i++ )); do
                    (( ! selected[$i] )) && { any_off=1; break; }
                done
                new_val=$(( any_off ? 1 : 0 ))
                for (( i = disabled_prefix + 1; i <= count; i++ )); do selected[$i]=$new_val; done
                ;;
            $'\n'|$'\r'|'')
                break
                ;;
        esac
        printf "\033[${total_lines}A"
        _wt_mp_render
    done

    printf '\033[?25h'
    trap - INT TERM

    if (( _escaped )); then
        _wt_multi_pick_result=()
        return 1
    fi

    for (( i = disabled_prefix + 1; i <= count; i++ )); do
        (( selected[$i] )) && _wt_multi_pick_result+=("${items[$i]}")
    done
    return 0
}

# ---------------------------------------------------------------------------
# Config management (~/.config/wt/<repo-basename>.conf)
# ---------------------------------------------------------------------------

_wt_config_file() {
    local main_wt
    main_wt=$(_wt_main_worktree) || return 1
    local repo_name=$(basename "$main_wt")
    echo "$HOME/.config/wt/${repo_name}.conf"
}

# Transient config layer — when active, config reads/writes use an in-memory
# override map instead of the config file.  Used by `wt create --configure`.
typeset -gA _wt_config_overrides
typeset -g  _wt_config_transient=false

# Batch-loaded config map — populated by _wt_config_load, avoids repeated grep calls.
typeset -gA _wt_conf_map

_wt_config_load() {
    _wt_conf_map=()
    local conf
    conf=$(_wt_config_file) || return 1
    [[ -f "$conf" ]] || return 1
    local _line
    while IFS= read -r _line; do
        [[ "$_line" == *=* ]] || continue
        _wt_conf_map[${_line%%=*}]="${_line#*=}"
    done < "$conf"
}

_wt_config_get() {
    local key="$1"
    # Check transient overrides first
    if (( ${+_wt_config_overrides[$key]} )); then
        echo "${_wt_config_overrides[$key]}"
        return 0
    fi
    # Check batch-loaded cache
    if (( ${+_wt_conf_map[$key]} )); then
        echo "${_wt_conf_map[$key]}"
        return 0
    fi
    local conf
    conf=$(_wt_config_file) || return 1
    [[ -f "$conf" ]] || return 1
    local line
    line=$(grep "^${key}=" "$conf" 2>/dev/null) || return 1
    echo "${line#${key}=}"
}

_wt_config_get_or() {
    local key="$1" default="$2"
    local val
    val=$(_wt_config_get "$key" 2>/dev/null) || val="$default"
    [[ -z "$val" ]] && val="$default"
    echo "$val"
}

_wt_config_set() {
    local key="$1" value="$2"
    if $_wt_config_transient; then
        _wt_config_overrides[$key]="$value"
        return 0
    fi
    local conf
    conf=$(_wt_config_file) || return 1
    mkdir -p "$(dirname "$conf")"
    if [[ -f "$conf" ]] && grep -q "^${key}=" "$conf" 2>/dev/null; then
        local tmp="${conf}.tmp"
        sed "s|^${key}=.*|${key}=${value}|" "$conf" > "$tmp" && mv "$tmp" "$conf" || { rm -f "$tmp"; return 1; }
    else
        echo "${key}=${value}" >> "$conf"
    fi
}

# Return the directory where worktrees are created.
# Falls back to sibling of main worktree if not configured.
_wt_worktree_parent() {
    local dir
    dir=$(_wt_config_get worktree_dir 2>/dev/null)
    if [[ -n "$dir" ]]; then
        echo "$dir"
    else
        local main_wt
        main_wt=$(_wt_main_worktree) || return 1
        dirname "$main_wt"
    fi
}

# Detect install commands for a directory based on lockfiles present.
# Outputs one command per line (a directory can have multiple lockfiles).
_wt_detect_install_cmd() {
    local dir="$1" lockfile
    for lockfile in "${_WT_LOCKFILE_NAMES[@]}"; do
        [[ -f "$dir/$lockfile" ]] && echo "${_WT_LOCKFILE_COMMANDS[$lockfile]}"
    done
}

# Find directories containing lockfiles up to depth 4, relative to <root>.
_wt_find_dep_dirs() {
    local root="$1"
    local -a name_args
    local lockfile first=true
    for lockfile in "${_WT_LOCKFILE_NAMES[@]}"; do
        $first && name_args+=(\( -name "$lockfile") || name_args+=(-o -name "$lockfile")
        first=false
    done
    name_args+=(\))
    find "$root" -maxdepth 4 \
        "${name_args[@]}" \
        -not -path '*/node_modules/*' \
        -not -path '*/.git/*' \
        2>/dev/null \
        | while IFS= read -r f; do
            dirname "${f#$root/}"
        done | sort -u
}

# Interactive setup — editor + dependency directories.
_wt_cmd_init() {
    local main_wt
    main_wt=$(_wt_main_worktree) || return 1

    # Read existing config (if any) for pre-selection
    local prev_editor prev_branch_start prev_branch_tool prev_workspaces prev_dep_dirs prev_sync_categories prev_worktree_dir prev_on_create prev_default_workspace
    prev_editor=$(_wt_config_get editor 2>/dev/null) || prev_editor=""
    prev_branch_start=$(_wt_config_get branch_start 2>/dev/null) || prev_branch_start=""
    prev_branch_tool=$(_wt_config_get branch_tool 2>/dev/null) || prev_branch_tool=""
    prev_workspaces=$(_wt_config_get workspaces 2>/dev/null) || prev_workspaces=""
    prev_dep_dirs=$(_wt_config_get dep_dirs 2>/dev/null) || prev_dep_dirs=""
    prev_sync_categories=$(_wt_config_get sync_categories 2>/dev/null) || prev_sync_categories=""
    prev_worktree_dir=$(_wt_config_get worktree_dir 2>/dev/null) || prev_worktree_dir=""
    prev_on_create=$(_wt_config_get on_create 2>/dev/null) || prev_on_create=""
    prev_default_workspace=$(_wt_config_get default_workspace 2>/dev/null) || prev_default_workspace=""

    if $_wt_config_transient; then
        echo ""
        _wt_heading "Configuring ${_WT_C_BOLD_YELLOW}one-off${_WT_C_RESET}${_WT_C_BOLD} worktree for ${_WT_C_CYAN}$(basename "$main_wt")${_WT_C_RESET} (will not be saved to repo-wide config file)"
    else
        echo ""
        _wt_heading "Setting up ${_WT_C_BOLD_YELLOW}wt${_WT_C_RESET}${_WT_C_BOLD} for ${_WT_C_CYAN}$(basename "$main_wt")"
    fi

    # --- Worktree location picker ---
    local default_parent=$(dirname "$main_wt")
    echo ""
    _wt_heading "Where should worktrees be created?"
    echo ""
    local _custom_wt_label="Enter custom path…"
    if [[ -n "$prev_worktree_dir" && "$prev_worktree_dir" != "$default_parent" ]]; then
        _wt_pick_init_sel=2
        _custom_wt_label="Enter custom path… ${_WT_C_DIM}(current: ${prev_worktree_dir})${_WT_C_RESET}"
    fi
    _wt_pick \
        "s" "Sibling of repository ${_WT_C_DIM}($default_parent)${_WT_C_RESET}" \
        "c" "$_custom_wt_label"
    local wt_dir_idx=$?
    if (( wt_dir_idx == 255 )); then
        echo ""
        echo "  ${_WT_C_RED}Operation cancelled.${_WT_C_RESET}"
        return 1
    fi
    local chosen_worktree_dir="$default_parent"
    if (( wt_dir_idx == 1 )); then
        echo ""
        _wt_text_input "Path: "
        case $? in
            1) echo "  ${_WT_C_RED}Operation cancelled.${_WT_C_RESET}"; return 1 ;;
            2) echo "  ${_WT_C_RED}No path entered. Operation cancelled.${_WT_C_RESET}"; return 1 ;;
        esac
        chosen_worktree_dir="${REPLY/#\~/$HOME}"
    fi

    # --- Editor picker ---
    local -a editor_keys editor_labels found_editors
    local label
    for ed in cursor windsurf code; do
        if command -v "$ed" &>/dev/null; then
            case "$ed" in
                cursor)   label="Cursor" ;;
                windsurf) label="Windsurf" ;;
                code)     label="VS Code" ;;
            esac
            editor_keys+=("$ed")
            editor_labels+=("$label")
        fi
    done

    local chosen_editor="code"
    echo ""
    _wt_heading "Select editor:"
    echo ""
    if (( ${#editor_keys} == 0 )); then
        echo "  ${_WT_C_YELLOW}No supported editors found in PATH.${_WT_C_RESET}"
        echo "  ${_WT_C_DIM}Defaulting to: code${_WT_C_RESET}"
    elif (( ${#editor_keys} == 1 )); then
        chosen_editor="${editor_keys[1]}"
        echo "  ${_WT_C_DIM}Detected only ${_WT_C_RESET} ${_WT_C_CYAN}${editor_labels[1]}${_WT_C_RESET}"
    else
        echo ""
        _wt_heading "Choose your editor:"
        echo ""
        local -a pick_args
        for (( i = 1; i <= ${#editor_keys}; i++ )); do
            pick_args+=("${editor_keys[$i]}" "${editor_labels[$i]}")
            [[ "${editor_keys[$i]}" == "$prev_editor" ]] && _wt_pick_init_sel=$i
        done
        _wt_pick "${pick_args[@]}"
        local idx=$?
        if (( idx == 255 )); then
            echo ""
            echo "  ${_WT_C_RED}Operation cancelled.${_WT_C_RESET}"
            return 1
        fi
        chosen_editor="${editor_keys[$(( idx + 1 ))]}"
    fi

    # --- Branch starting point picker ---
    local default_branch=$(_wt_default_branch "$main_wt")
    echo ""
    _wt_heading "Default starting point for new branches (overridable via ${_WT_C_BOLD_YELLOW}--from${_WT_C_RESET}${_WT_C_BOLD}):"
    echo ""
    local _custom_label="Type in branch name"
    if [[ -n "$prev_branch_start" && "$prev_branch_start" != "main" ]]; then
        _wt_pick_init_sel=2
        _custom_label="Type in branch name (current: ${prev_branch_start})"
    fi
    _wt_pick \
        "m" "$default_branch" \
        "c" "$_custom_label"
    local branch_idx=$?
    if (( branch_idx == 255 )); then
        echo ""
        echo "  ${_WT_C_RED}Operation cancelled.${_WT_C_RESET}"
        return 1
    fi
    local chosen_branch_start="main"
    if (( branch_idx == 1 )); then
        echo ""
        _wt_text_input "Branch name: "
        case $? in
            1) echo "  ${_WT_C_RED}Operation cancelled.${_WT_C_RESET}"; return 1 ;;
            2) echo "  ${_WT_C_RED}No branch name entered. Operation cancelled.${_WT_C_RESET}"; return 1 ;;
        esac
        chosen_branch_start="$REPLY"
    fi

    # --- Graphite detection ---
    local chosen_branch_tool="git"
    if command -v gt &>/dev/null; then
        echo ""
        _wt_heading "Use Graphite for branch creation?"
        echo ""
        [[ "$prev_branch_tool" == "graphite" ]] && _wt_pick_init_sel=2
        _wt_pick \
            "n" "No" \
            "y" "Yes"
        local gt_idx=$?
        if (( gt_idx == 255 )); then
            echo ""
            echo "  ${_WT_C_RED}Operation cancelled.${_WT_C_RESET}"
            return 1
        fi
        (( gt_idx == 1 )) && chosen_branch_tool="graphite"
    fi

    # --- Workspace file picker ---
    local -a ws_found
    local ws_entry
    while IFS= read -r ws_entry; do
        [[ -n "$ws_entry" ]] && ws_found+=("$ws_entry")
    done < <(_wt_find_workspace_files "$main_wt")

    local chosen_workspaces=""
    if (( ${#ws_found} == 1 )); then
        chosen_workspaces="${ws_found[1]}"
        echo "  ${_WT_C_DIM}Detected workspace file:${_WT_C_RESET} ${_WT_C_CYAN}${ws_found[1]}${_WT_C_RESET}"
    elif (( ${#ws_found} > 1 )); then
        echo ""
        _wt_heading "Select workspace files to choose between when opening worktrees:"
        echo ""
        if [[ -n "$prev_workspaces" ]]; then
            _wt_mp_init_selected=()
            for (( i = 1; i <= ${#ws_found}; i++ )); do
                if [[ ",$prev_workspaces," == *",${ws_found[$i]},"* ]]; then
                    _wt_mp_init_selected+=(1)
                else
                    _wt_mp_init_selected+=(0)
                fi
            done
        fi
        _wt_multi_pick --all "${ws_found[@]}"
        if (( $? != 0 )); then
            echo ""
            echo "  ${_WT_C_RED}Operation cancelled.${_WT_C_RESET}"
            return 1
        fi
        chosen_workspaces="${(j:,:)_wt_multi_pick_result}"
    fi

    # --- Dependency folder picker ---
    # Build scope prefixes from selected workspace directories (skip root-level ones)
    local -a _ws_scopes
    if [[ -n "$chosen_workspaces" ]]; then
        local _ws_entry _ws_dir
        for _ws_entry in ${(s:,:)chosen_workspaces}; do
            _ws_dir=$(dirname "$_ws_entry")
            [[ "$_ws_dir" != "." ]] && _ws_scopes+=("$_ws_dir")
        done
    fi

    # Collect all dep dirs first
    local -a _all_dep_dirs
    local dir
    while IFS= read -r dir; do
        [[ -z "$dir" ]] && continue
        [[ -n "$(_wt_detect_install_cmd "$main_wt/$dir")" ]] && _all_dep_dirs+=("$dir")
    done < <(_wt_find_dep_dirs "$main_wt")

    # Filter to workspace scopes if any non-root workspaces were selected
    local -a dep_dirs_found dep_labels
    local cmds _in_scope _scope
    for dir in "${_all_dep_dirs[@]}"; do
        if (( ${#_ws_scopes} > 0 )); then
            _in_scope=false
            for _scope in "${_ws_scopes[@]}"; do
                if [[ "$dir" == "$_scope" || "$dir" == "$_scope"/* ]]; then
                    _in_scope=true
                    break
                fi
            done
            $_in_scope || continue
        fi
        cmds=$(_wt_detect_install_cmd "$main_wt/$dir")
        dep_dirs_found+=("$dir")
        dep_labels+=("$dir ${_WT_C_DIM}(${cmds//$'\n'/, })${_WT_C_RESET}")
    done

    local chosen_dep_dirs=""
    if (( ${#dep_dirs_found} > 0 )); then
        if (( ${#_ws_scopes} > 0 )); then
            echo ""
            _wt_heading "Select dependency directories to install on worktree creation ${_WT_C_DIM}(filtered to selected workspaces)${_WT_C_RESET}${_WT_C_BOLD}:"
        else
            echo ""
            _wt_heading "Select dependency directories to install on worktree creation:"
        fi
        echo ""
        # Pre-select from previous config; fall back to --all on first run
        if [[ -n "$prev_dep_dirs" ]]; then
            _wt_mp_init_selected=()
            for (( i = 1; i <= ${#dep_dirs_found}; i++ )); do
                if [[ ",$prev_dep_dirs," == *",${dep_dirs_found[$i]},"* ]]; then
                    _wt_mp_init_selected+=(1)
                else
                    _wt_mp_init_selected+=(0)
                fi
            done
        fi
        _wt_multi_pick --all "${dep_labels[@]}"
        if (( $? != 0 )); then
            echo ""
            echo "  ${_WT_C_RED}Operation cancelled.${_WT_C_RESET}"
            return 1
        fi
        local -a selected_dirs
        local clean
        for label in "${_wt_multi_pick_result[@]}"; do
            # Extract the directory path (strip the dimmed command suffix)
            clean="${label%% *}"
            selected_dirs+=("$clean")
        done
        chosen_dep_dirs="${(j:,:)selected_dirs}"
    else
        echo "  ${_WT_C_DIM}No dependency directories detected.${_WT_C_RESET}"
    fi

    # --- Gitignored file sync category picker ---
    echo ""
    _wt_heading "Select gitignored file categories to sync to new worktrees:"
    echo ""

    # Ensure patterns are built (lazy init)
    _wt_build_patterns

    # Detect which categories have entries — one grep per category, not per entry
    local -A detected_categories
    local category_key gitignored
    gitignored=$(git -C "$main_wt" ls-files --others --ignored --directory --exclude-standard 2>/dev/null \
        | grep -v -E "$_WT_NOISE_PATTERN")
    if [[ -n "$gitignored" ]]; then
        local -a known_patterns
        for category_key in "${_WT_SYNC_CATEGORY_KEYS[@]}"; do
            [[ -z "${_WT_SYNC_CATEGORY_PATTERNS[$category_key]:-}" ]] && continue
            if echo "$gitignored" | grep -qE "${_WT_SYNC_CATEGORY_PATTERNS[$category_key]}"; then
                detected_categories[$category_key]=1
            fi
            known_patterns+=("${_WT_SYNC_CATEGORY_PATTERNS[$category_key]}")
        done
    fi

    # Build picker items: fixed categories first, then toggleable, in defined order
    local -a picker_labels picker_category_keys
    local disabled_count=0
    # Fixed categories (disabled) first
    for category_key in "${_WT_SYNC_CATEGORY_KEYS[@]}"; do
        [[ -z "${detected_categories[$category_key]:-}" ]] && continue
        [[ "${_WT_SYNC_CATEGORY_DEFAULTS[$category_key]}" != "fixed" ]] && continue
        picker_labels+=("${_WT_SYNC_CATEGORY_LABELS[$category_key]} ${_WT_C_DIM}(installed separately)${_WT_C_RESET}")
        picker_category_keys+=("$category_key")
        (( disabled_count++ ))
    done
    # Toggleable categories — pre-select from previous config or defaults
    _wt_mp_init_selected=()
    for category_key in "${_WT_SYNC_CATEGORY_KEYS[@]}"; do
        [[ -z "${detected_categories[$category_key]:-}" ]] && continue
        [[ "${_WT_SYNC_CATEGORY_DEFAULTS[$category_key]}" == "fixed" ]] && continue
        picker_labels+=("${_WT_SYNC_CATEGORY_LABELS[$category_key]}")
        picker_category_keys+=("$category_key")
        if [[ -n "$prev_sync_categories" ]]; then
            # Re-run: match against saved config
            if [[ ",$prev_sync_categories," == *",$category_key,"* ]]; then
                _wt_mp_init_selected+=(1)
            else
                _wt_mp_init_selected+=(0)
            fi
        else
            # First run: use hardcoded defaults
            if [[ "${_WT_SYNC_CATEGORY_DEFAULTS[$category_key]}" == "on" ]]; then
                _wt_mp_init_selected+=(1)
            else
                _wt_mp_init_selected+=(0)
            fi
        fi
    done

    local chosen_sync_categories=""
    if (( ${#picker_labels} > disabled_count )); then
        _wt_multi_pick --disabled-prefix "$disabled_count" "${picker_labels[@]}"
        if (( $? != 0 )); then
            echo ""
            echo "  ${_WT_C_RED}Operation cancelled.${_WT_C_RESET}"
            return 1
        fi

        # Map selected labels back to category keys
        local -a selected_categories
        local found
        for (( i = disabled_count + 1; i <= ${#picker_labels}; i++ )); do
            found=false
            for sel_entry in "${_wt_multi_pick_result[@]}"; do
                if [[ "$sel_entry" == "${picker_labels[$i]}" ]]; then
                    found=true
                    break
                fi
            done
            $found && selected_categories+=("${picker_category_keys[$i]}")
        done
        chosen_sync_categories="${(j:,:)selected_categories}"
    elif (( disabled_count > 0 )); then
        echo "  ${_WT_C_DIM}No syncable gitignored files detected.${_WT_C_RESET}"
    else
        echo "  ${_WT_C_DIM}No gitignored files detected.${_WT_C_RESET}"
    fi

    # --- Post-create action picker ---
    local ed_label
    ed_label=$(_wt_editor_name "$chosen_editor")
    echo ""
    _wt_heading "After creating a worktree:"
    echo ""
    local -a _oc_keys=("open" "cd" "nothing" "ask")
    local -a _oc_labels=("Open in $ed_label" "cd into worktree" "Do nothing" "Ask every time")
    _wt_pick_init_sel=4
    if [[ -n "$prev_on_create" ]]; then
        for (( i = 1; i <= ${#_oc_keys}; i++ )); do
            [[ "${_oc_keys[$i]}" == "$prev_on_create" ]] && { _wt_pick_init_sel=$i; break; }
        done
    fi
    local -a _oc_pick_args=()
    for (( i = 1; i <= ${#_oc_keys}; i++ )); do
        _oc_pick_args+=("${_oc_keys[$i]}" "${_oc_labels[$i]}")
    done
    _wt_pick "${_oc_pick_args[@]}"
    local _oc_idx=$?
    if (( _oc_idx == 255 )); then
        echo ""
        echo "  ${_WT_C_RED}Operation cancelled.${_WT_C_RESET}"
        return 1
    fi
    local chosen_on_create="${_oc_keys[$(( _oc_idx + 1 ))]}"

    # --- Default workspace picker (only when multiple workspaces) ---
    local chosen_default_workspace=""
    if [[ "$chosen_workspaces" == *","* ]]; then
        echo ""
        _wt_heading "Select workspace for open/cd actions (filtered to selected workspaces):"
        echo ""
        local -a _dw_keys=() _dw_labels=()
        local -a _dw_ws_list
        IFS=',' read -rA _dw_ws_list <<< "$chosen_workspaces"
        for _dw_ws in "${_dw_ws_list[@]}"; do
            _dw_keys+=("$_dw_ws")
            local _dw_label="${_dw_ws%.code-workspace}"
            if [[ "$(dirname "$_dw_ws")" == "." ]]; then
                _dw_labels+=("$_dw_label ${_WT_C_DIM}(root)${_WT_C_RESET}")
            else
                _dw_labels+=("$_dw_label")
            fi
        done
        _dw_keys+=("ask")
        _dw_labels+=("Ask every time")
        _wt_pick_init_sel=${#_dw_keys}
        if [[ -n "$prev_default_workspace" ]]; then
            for (( i = 1; i <= ${#_dw_keys}; i++ )); do
                [[ "${_dw_keys[$i]}" == "$prev_default_workspace" ]] && { _wt_pick_init_sel=$i; break; }
            done
        fi
        local -a _dw_pick_args=()
        for (( i = 1; i <= ${#_dw_keys}; i++ )); do
            _dw_pick_args+=("${_dw_keys[$i]}" "${_dw_labels[$i]}")
        done
        _wt_pick "${_dw_pick_args[@]}"
        local _dw_idx=$?
        if (( _dw_idx == 255 )); then
            echo ""
            echo "  ${_WT_C_RED}Operation cancelled.${_WT_C_RESET}"
            return 1
        fi
        chosen_default_workspace="${_dw_keys[$(( _dw_idx + 1 ))]}"
    fi

    # --- Save config ---
    _wt_config_set "worktree_dir" "$chosen_worktree_dir"
    _wt_config_set "editor" "$chosen_editor"
    _wt_config_set "branch_start" "$chosen_branch_start"
    _wt_config_set "branch_tool" "$chosen_branch_tool"
    _wt_config_set "dep_dirs" "$chosen_dep_dirs"
    _wt_config_set "sync_categories" "$chosen_sync_categories"
    _wt_config_set "workspaces" "$chosen_workspaces"
    _wt_config_set "on_create" "$chosen_on_create"
    _wt_config_set "default_workspace" "$chosen_default_workspace"

    echo ""
    if $_wt_config_transient; then
        echo "${_WT_C_GREEN}${_WT_C_BOLD}Configured.${_WT_C_RESET}"
    else
        local conf
        conf=$(_wt_config_file)
        echo "${_WT_C_GREEN}${_WT_C_BOLD}Setup complete.${_WT_C_RESET} ${_WT_C_DIM}Config saved to $conf${_WT_C_RESET}"
    fi
}

# Ensure setup has been run; if not, run it.
_wt_ensure_setup() {
    local conf
    conf=$(_wt_config_file) || return 1
    if [[ ! -f "$conf" ]]; then
        echo ""
        echo "  ${_WT_C_YELLOW}No wt config found for this repo.${_WT_C_RESET} ${_WT_C_DIM}Running setup…${_WT_C_RESET}"
        _wt_cmd_init
    fi
    # Batch-load config into memory to avoid repeated grep calls
    (( ${#_wt_conf_map} == 0 )) && _wt_config_load
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

typeset -g _wt_repo_root_cache=""
_wt_repo_root() {
    if [[ -z "${_wt_repo_root_cache:-}" ]]; then
        _wt_repo_root_cache=$(git rev-parse --show-toplevel 2>/dev/null) || {
            echo "${_WT_C_RED}Error: not inside a git repository.${_WT_C_RESET}" >&2
            return 1
        }
    fi
    echo "$_wt_repo_root_cache"
}

typeset -g _wt_main_wt_cache=""
_wt_main_worktree() {
    if [[ -z "${_wt_main_wt_cache:-}" ]]; then
        _wt_main_wt_cache=$(git worktree list --porcelain | head -1 | sed 's/^worktree //')
    fi
    echo "$_wt_main_wt_cache"
}

_wt_next_name() {
    local repo_root="$1"
    local repo_name=$(basename "$repo_root")
    local parent
    parent=$(_wt_worktree_parent) || parent=$(dirname "$repo_root")
    local max=0 n

    for dir in "$parent/${repo_name}"-wt-*(N/); do
        n="${dir##*-wt-}"
        if [[ "$n" =~ '^[0-9]+$' ]] && (( n > max )); then
            max=$n
        fi
    done

    echo "${repo_name}-wt-$(( max + 1 ))"
}

_wt_default_branch() {
    local main_wt="$1"
    # Try origin/HEAD symbolic ref first
    local ref
    ref=$(git -C "$main_wt" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null)
    if [[ -n "$ref" ]]; then
        echo "${ref##refs/remotes/origin/}"
        return
    fi
    # Fallback: check if main or master exists
    if git -C "$main_wt" rev-parse --verify refs/heads/main &>/dev/null; then
        echo "main"
    elif git -C "$main_wt" rev-parse --verify refs/heads/master &>/dev/null; then
        echo "master"
    else
        echo "main"
    fi
}

_wt_read_theme() {
    local ws_file="$1" line
    [[ -f "$ws_file" ]] || return 1
    while IFS= read -r line; do
        if [[ "$line" == *'"workbench.colorTheme"'* ]]; then
            line="${line#*\"workbench.colorTheme\"*:*\"}"
            line="${line%%\"*}"
            [[ -n "$line" ]] && { echo "$line"; return 0; }
        fi
    done < "$ws_file"
    return 1
}

# Read the theme from a worktree — checks workspace files first, then editor settings files.
_wt_read_worktree_theme() {
    local wt_path="$1"
    local t ws_file
    while IFS= read -r ws_file; do
        [[ -z "$ws_file" ]] && continue
        t=$(_wt_read_theme "$wt_path/$ws_file")
        [[ -n "$t" ]] && { echo "$t"; return 0; }
    done < <(_wt_find_workspace_files "$wt_path")
    # Fall back to editor settings files
    local settings_dir
    for settings_dir in .vscode .cursor .windsurf; do
        t=$(_wt_read_theme "$wt_path/$settings_dir/settings.json")
        [[ -n "$t" ]] && { echo "$t"; return 0; }
    done
    return 1
}

_wt_next_theme() {
    local main_wt="$1"
    local parent
    parent=$(_wt_worktree_parent) || parent=$(dirname "$main_wt")

    local -A used_map
    local t

    for wt in "$parent"/*(/N); do
        [[ "$wt" == "$main_wt" ]] && continue
        t=$(_wt_read_worktree_theme "$wt")
        [[ -n "$t" ]] && used_map[$t]=1
    done

    local theme
    for theme in "${_WT_THEMES[@]}"; do
        (( ${+used_map[$theme]} )) || { echo "$theme"; return 0; }
    done

    echo "${_WT_THEMES[1]}"
    return 1
}

_wt_set_theme() {
    local ws_file="$1" theme="$2"
    [[ -f "$ws_file" ]] || return 1

    python3 - "$ws_file" "$theme" <<'PYEOF'
import re, sys

ws_file, theme = sys.argv[1], sys.argv[2]
with open(ws_file) as f:
    text = f.read()

if re.search(r'"workbench\.colorTheme"', text):
    text = re.sub(
        r'("workbench\.colorTheme"\s*:\s*)"[^"]*"',
        rf'\1"{theme}"',
        text,
    )
elif re.search(r'"settings"\s*:\s*\{', text):
    text = re.sub(
        r'("settings"\s*:\s*\{)',
        rf'\1\n    "workbench.colorTheme": "{theme}",',
        text,
        count=1,
    )
else:
    text = re.sub(
        r'(\{)',
        rf'\1\n    "workbench.colorTheme": "{theme}",',
        text,
        count=1,
    )

with open(ws_file, "w") as f:
    f.write(text)
PYEOF
}

# Return the editor-specific settings directory name (.vscode, .cursor, .windsurf)
_wt_editor_settings_dir() {
    case "${1:-code}" in
        cursor)   echo ".cursor" ;;
        windsurf) echo ".windsurf" ;;
        code)     echo ".vscode" ;;
        *)        echo ".vscode" ;;
    esac
}

# Classify a gitignored entry into a sync category. Returns the category key.
_wt_classify_category() {
    _wt_build_patterns
    local entry="$1" category_key
    for category_key in "${_WT_SYNC_CATEGORY_KEYS[@]}"; do
        [[ -z "${_WT_SYNC_CATEGORY_PATTERNS[$category_key]:-}" ]] && continue
        if echo "$entry" | grep -qE "${_WT_SYNC_CATEGORY_PATTERNS[$category_key]}"; then
            echo "$category_key"
            return
        fi
    done
}

# Set the theme in the editor's settings.json (folder-level, persists across reopen)
_wt_set_editor_theme() {
    local wt_path="$1" theme="$2" editor="${3:-code}"
    local settings_dir
    settings_dir=$(_wt_editor_settings_dir "$editor")
    local dir="$wt_path/$settings_dir"
    local settings_file="$dir/settings.json"

    mkdir -p "$dir"
    [[ -f "$settings_file" ]] || echo '{}' > "$settings_file"
    _wt_set_theme "$settings_file" "$theme"
}

_wt_sync_gitignored() {
    _wt_build_patterns
    local target_dir="$1"
    local main_wt="$2"

    local sync_categories
    sync_categories=$(_wt_config_get sync_categories 2>/dev/null) || sync_categories=""

    # Nothing configured — skip
    [[ -z "$sync_categories" ]] && return 1

    # Build a single combined regex from all enabled sync categories (one grep
    # instead of calling _wt_classify_category per entry).
    local combined_pattern="" category_key
    for category_key in "${_WT_SYNC_CATEGORY_KEYS[@]}"; do
        [[ ",$sync_categories," != *",$category_key,"* ]] && continue
        [[ -z "${_WT_SYNC_CATEGORY_PATTERNS[$category_key]:-}" ]] && continue
        if [[ -n "$combined_pattern" ]]; then
            combined_pattern="$combined_pattern|${_WT_SYNC_CATEGORY_PATTERNS[$category_key]}"
        else
            combined_pattern="${_WT_SYNC_CATEGORY_PATTERNS[$category_key]}"
        fi
    done
    [[ -z "$combined_pattern" ]] && return 1

    # Build rsync exclude args for noise files
    local -a rsync_excludes=()
    local _nf
    for _nf in "${_WT_NOISE_FILES[@]}"; do rsync_excludes+=(--exclude "$_nf"); done

    # Collect all matching entries in one pass (avoids per-entry subshells)
    local -a entries=()
    entries=("${(@f)$(git -C "$main_wt" ls-files --others --ignored --directory --exclude-standard 2>/dev/null \
        | grep -v -E "$_WT_NOISE_PATTERN" \
        | grep -E "$combined_pattern")}")

    # Separate directories (bulk rsync) from individual files
    local entry file_list
    file_list=$(mktemp) || { echo "${_WT_C_RED}Error: mktemp failed${_WT_C_RESET}" >&2; return 1; }
    for entry in "${entries[@]}"; do
        [[ -z "$entry" ]] && continue
        if [[ "$entry" == */ ]]; then
            # Directory entry — rsync in bulk
            [[ -d "$main_wt/$entry" ]] || continue
            mkdir -p "$target_dir/$entry" 2>/dev/null
            rsync -a "${rsync_excludes[@]}" "$main_wt/$entry" "$target_dir/$entry"
        else
            # File entry — collect for batched rsync
            [[ -f "$main_wt/$entry" ]] && echo "$entry" >> "$file_list"
        fi
    done

    # Batch-copy all individual files in one rsync call
    if [[ -s "$file_list" ]]; then
        rsync -a --files-from="$file_list" "$main_wt/" "$target_dir/"
    fi
    [[ -n "$file_list" ]] && rm -f "$file_list"
}

# Check if a .code-workspace file references a target directory (JSONC-aware).
_wt_workspace_refs_dir() {
    local ws_file="$1" target_dir="$2"
    python3 - "$ws_file" "$target_dir" <<'PYEOF'
import re, json, sys, os

ws_file, target_dir = sys.argv[1], sys.argv[2]
try:
    text = open(ws_file).read()
    # Strip JSONC single-line comments and trailing commas before closing } or ]
    text = re.sub(r'//[^\n]*', '', text)
    text = re.sub(r',\s*([}\]])', r'\1', text)
    data = json.loads(text)
    folders = data.get("folders", [])
    for f in folders:
        path = f.get("path", "")
        # Normalise: folder paths are relative to the workspace file's directory
        ws_dir = os.path.dirname(ws_file)
        abs_folder = os.path.normpath(os.path.join(ws_dir, path))
        abs_target = os.path.normpath(target_dir)
        if abs_target == abs_folder or abs_target.startswith(abs_folder + os.sep):
            sys.exit(0)
    sys.exit(1)
except Exception:
    sys.exit(1)
PYEOF
}

# Detect the best workspace file to open for a given worktree.
# Args: <wt_root> [<cwd_hint>]
#   wt_root  — the new worktree root
#   cwd_hint — the caller's CWD in the *main* worktree (optional)
_wt_detect_workspace() {
    local wt_root="$1"
    local cwd_hint="${2:-}"
    local main_wt
    main_wt=$(_wt_main_worktree)

    # Load configured workspaces to filter against
    local _ws_config _ws_rel
    _ws_config=$(_wt_config_get workspaces 2>/dev/null) || _ws_config=""

    # Helper: check if a workspace is in the configured list (or allow all if empty).
    # Also matches renamed files (with worktree name suffix stripped).
    _wt_ws_allowed() {
        [[ -z "$_ws_config" ]] && return 0
        _ws_rel="${1#$wt_root/}"
        [[ ",$_ws_config," == *",$_ws_rel,"* ]] && return 0
        # Strip worktree name suffix: foo.wt-name.code-workspace → foo.code-workspace
        local _wt_name=$(basename "$wt_root")
        local _ws_stripped="${_ws_rel%.code-workspace}"
        _ws_stripped="${_ws_stripped%.${_wt_name}}.code-workspace"
        [[ ",$_ws_config," == *",$_ws_stripped,"* ]]
    }

    # Translate cwd_hint to a relative path inside the worktree
    local rel_dir=""
    if [[ -n "$cwd_hint" && -n "$main_wt" ]]; then
        local _wt_parent
        _wt_parent=$(_wt_worktree_parent 2>/dev/null) || _wt_parent=$(dirname "$main_wt")
        case "$cwd_hint" in
            "$main_wt"/*)
                rel_dir="${cwd_hint#$main_wt/}"
                ;;
            "$wt_root"/*)
                rel_dir="${cwd_hint#$wt_root/}"
                ;;
            "$_wt_parent"/*)
                # Inside a sibling secondary worktree — strip <parent>/<wt-name>/
                local _sibling_rel="${cwd_hint#$_wt_parent/}"
                rel_dir="${_sibling_rel#*/}"
                # If stripping left the whole string, we're at the sibling root
                [[ "$rel_dir" == "$_sibling_rel" ]] && rel_dir=""
                ;;
        esac
    fi

    local search_dir="$wt_root${rel_dir:+/$rel_dir}"

    # 1. Look for sibling .code-workspace in the search directory
    local ws
    for ws in "$search_dir"/*.code-workspace(N); do
        _wt_ws_allowed "$ws" && { echo "${ws#$wt_root/}"; return 0; }
    done

    # 2. Walk up max 3 parent levels looking for a workspace whose folders ref the target
    local check_dir="$search_dir"
    local depth=0
    while [[ "$check_dir" != "$wt_root" && $depth -lt 3 ]]; do
        check_dir=$(dirname "$check_dir")
        for ws in "$check_dir"/*.code-workspace(N); do
            if _wt_ws_allowed "$ws" && _wt_workspace_refs_dir "$ws" "$search_dir"; then
                echo "${ws#$wt_root/}"
                return 0
            fi
        done
        (( depth++ ))
    done

    # 3. Fall back to root-level workspace
    for ws in "$wt_root"/*.code-workspace(N); do
        _wt_ws_allowed "$ws" && { echo "${ws#$wt_root/}"; return 0; }
    done

    # No workspace file found
    return 1
}

# Calculate the equivalent directory in a target worktree based on the caller's
# current position. Falls back to the target root if the equivalent path doesn't exist.
# Args: <target_wt_root> <current_pwd>
_wt_equiv_dir() {
    local target="$1" cwd="$2"
    local main_wt
    main_wt=$(_wt_main_worktree 2>/dev/null) || { echo "$target"; return; }

    local rel=""
    case "$cwd" in
        "$main_wt"/*)
            rel="${cwd#$main_wt/}"
            ;;
        "$target"/*)
            rel="${cwd#$target/}"
            ;;
        *)
            # Check if inside a sibling secondary worktree
            local _wt_parent
            _wt_parent=$(_wt_worktree_parent 2>/dev/null) || _wt_parent=$(dirname "$main_wt")
            if [[ "$cwd" == "$_wt_parent"/* ]]; then
                local _sibling_rel="${cwd#$_wt_parent/}"
                rel="${_sibling_rel#*/}"
                [[ "$rel" == "$_sibling_rel" ]] && rel=""
            fi
            ;;
    esac

    if [[ -n "$rel" && -d "$target/$rel" ]]; then
        echo "$target/$rel"
    else
        echo "$target"
    fi
}

# Resolve the default workspace for a worktree from config.
# Args: <wt_path> <workspaces_array_name>
# Sets REPLY to the resolved workspace name, or "" if not found/configured as "ask".
_wt_resolve_default_workspace() {
    local wt_path="$1"
    shift
    local -a workspaces=("$@")
    REPLY=""
    local _dw_config
    _dw_config=$(_wt_config_get default_workspace 2>/dev/null) || _dw_config=""
    [[ -z "$_dw_config" || "$_dw_config" == "ask" ]] && return 1
    local _wt_name=$(basename "$wt_path")
    local ws _orig
    for ws in "${workspaces[@]}"; do
        if [[ "$ws" == "$_dw_config" ]]; then
            REPLY="$ws"; return 0
        fi
        _orig="${ws%.${_wt_name}.code-workspace}.code-workspace"
        if [[ "$_orig" == "$_dw_config" ]]; then
            REPLY="$ws"; return 0
        fi
    done
    return 1
}

# Build picker args for workspace selection. Sets caller-scope arrays:
#   _ws_pick_args, _ws_root_ws, _ws_nested_ws
_wt_build_ws_pick_args() {
    local wt_path="$1"
    shift
    local -a workspaces=("$@")
    _ws_root_ws=""
    _ws_nested_ws=()
    _ws_pick_args=()
    local ws
    for ws in "${workspaces[@]}"; do
        if [[ "$(dirname "$ws")" == "." ]]; then
            _ws_root_ws="$ws"
        else
            _ws_nested_ws+=("$ws")
        fi
    done
    if [[ -n "$_ws_root_ws" ]]; then
        local root_label="${_ws_root_ws%.code-workspace}"
        _ws_pick_args+=("$_ws_root_ws" "$root_label ${_WT_C_DIM}(root)${_WT_C_RESET}")
    else
        _ws_pick_args+=("." "Worktree root ${_WT_C_DIM}($(basename "$wt_path"))${_WT_C_RESET}")
    fi
    for ws in "${_ws_nested_ws[@]}"; do
        _ws_pick_args+=("$ws" "${ws%.code-workspace}")
    done
}

# Inline text input with escape-to-cancel and backspace support.
# Sets REPLY to entered text. Returns 1 on cancel (escape), 2 on empty input.
_wt_text_input() {
    local prompt="$1"
    REPLY=""
    local _ch
    printf "  %s" "$prompt"
    while true; do
        read -rsk 1 _ch
        case "$_ch" in
            $'\033')
                REPLY=""
                printf '\n'
                return 1
                ;;
            $'\n'|$'\r'|'')
                printf '\n'
                [[ -z "$REPLY" ]] && return 2
                return 0
                ;;
            $'\177'|$'\b')
                if [[ -n "$REPLY" ]]; then
                    REPLY="${REPLY%?}"
                    printf '\b \b'
                fi
                ;;
            *)
                REPLY+="$_ch"
                printf '%s' "$_ch"
                ;;
        esac
    done
}

# Resolve configured workspace filenames for a worktree, accounting for renames.
# Sets caller-scope array 'reply' with resolved workspace relative paths.
_wt_resolve_workspaces() {
    local wt_path="$1"
    reply=()
    local ws_config
    ws_config=$(_wt_config_get workspaces 2>/dev/null) || ws_config=""
    [[ -z "$ws_config" ]] && return
    local -a _config_ws
    IFS=',' read -rA _config_ws <<< "$ws_config"
    local _wt_name=$(basename "$wt_path")
    local _cw _renamed
    for _cw in "${_config_ws[@]}"; do
        _renamed="${_cw%.code-workspace}.${_wt_name}.code-workspace"
        if [[ -f "$wt_path/$_renamed" ]]; then
            reply+=("$_renamed")
        elif [[ -f "$wt_path/$_cw" ]]; then
            reply+=("$_cw")
        fi
    done
}

_wt_open() {
    local wt_path="$1"
    local editor_override="$2"
    _wt_last_pick_lines=0

    local editor="${editor_override:-$(_wt_config_get editor)}"
    editor="${editor:-code}"

    # Load workspaces from config and resolve to disk filenames
    _wt_resolve_workspaces "$wt_path"
    local -a workspaces=("${reply[@]}")

    if (( ${#workspaces} <= 1 )); then
        # 0 or 1 workspace — use detect_workspace for auto-selection
        local ws_file
        ws_file=$(_wt_detect_workspace "$wt_path" "$PWD") || ws_file=""
        if [[ -n "$ws_file" ]]; then
            "$editor" -n "$wt_path/$ws_file"
        else
            "$editor" -n "$wt_path"
        fi
    else
        # Multiple workspaces — check default_workspace config before showing picker
        if _wt_resolve_default_workspace "$wt_path" "${workspaces[@]}"; then
            if [[ "$REPLY" == "." ]]; then
                "$editor" -n "$wt_path"
            else
                "$editor" -n "$wt_path/$REPLY"
            fi
            return
        fi

        # Show a picker
        local _ws_root_ws=""
        local -a _ws_nested_ws _ws_pick_args
        _wt_build_ws_pick_args "$wt_path" "${workspaces[@]}"

        local _num_options=$(( ${#_ws_pick_args} / 2 ))
        echo ""
        _wt_heading "Open workspace:"
        echo ""
        _wt_pick "${_ws_pick_args[@]}"
        local ws_idx=$?
        _wt_last_pick_lines=$(( 3 + _num_options ))
        if (( ws_idx == 255 )); then
            echo ""
            echo "  ${_WT_C_DIM}Cancelled.${_WT_C_RESET}"
            _wt_last_pick_lines=$(( _wt_last_pick_lines + 2 ))
            return 0
        fi
        if (( ws_idx == 0 )); then
            if [[ -n "$_ws_root_ws" ]]; then
                "$editor" -n "$wt_path/$_ws_root_ws"
            else
                "$editor" -n "$wt_path"
            fi
        else
            local ws_rel="${_ws_nested_ws[$(( ws_idx ))]}"
            "$editor" -n "$wt_path/$ws_rel"
        fi
    fi
}

_wt_cd() {
    local wt_path="$1"
    local cwd="${2:-$PWD}"
    _wt_last_pick_lines=0

    # Load workspaces from config and resolve to disk filenames
    _wt_resolve_workspaces "$wt_path"
    local -a workspaces=("${reply[@]}")

    if (( ${#workspaces} <= 1 )); then
        # 0 or 1 workspace — use equiv_dir
        cd "$(_wt_equiv_dir "$wt_path" "$cwd")"
    else
        # Multiple workspaces — check default_workspace config before showing picker
        if _wt_resolve_default_workspace "$wt_path" "${workspaces[@]}"; then
            if [[ "$REPLY" == "." || "$(dirname "$REPLY")" == "." ]]; then
                cd "$wt_path"
            else
                cd "$wt_path/$(dirname "$REPLY")"
            fi
            return
        fi

        # Show a directory picker
        local _ws_root_ws=""
        local -a _ws_nested_ws _ws_pick_args
        _wt_build_ws_pick_args "$wt_path" "${workspaces[@]}"

        local _num_options=$(( ${#_ws_pick_args} / 2 ))
        echo ""
        _wt_heading "cd to:"
        echo ""
        _wt_pick "${_ws_pick_args[@]}"
        local cd_idx=$?
        _wt_last_pick_lines=$(( 3 + _num_options ))
        if (( cd_idx == 255 )); then
            echo ""
            echo "  ${_WT_C_DIM}Cancelled.${_WT_C_RESET}"
            _wt_last_pick_lines=$(( _wt_last_pick_lines + 2 ))
            return 0
        fi
        if (( cd_idx == 0 )); then
            cd "$wt_path"
        else
            local ws_rel="${_ws_nested_ws[$(( cd_idx ))]}"
            cd "$wt_path/$(dirname "$ws_rel")"
        fi
    fi
}

_wt_editor_name() {
    case "${1:-code}" in
        cursor)   echo "Cursor" ;;
        windsurf) echo "Windsurf" ;;
        code)     echo "VS Code" ;;
        *)        echo "$1" ;;
    esac
}

# Global for cross-function init tracking
typeset -g _wt_init_status_dir=""

_wt_worktree_init() {
    setopt LOCAL_OPTIONS NO_MONITOR
    local wt_path="$1"
    local main_wt="$2"

    # Read config file once — avoids repeated _wt_config_get calls which each
    # spawn git + head + sed subprocesses via _wt_config_file/_wt_main_worktree.
    local _conf_file="$HOME/.config/wt/${main_wt:t}.conf"
    local _conf_content=""
    [[ -f "$_conf_file" ]] && _conf_content=$(<"$_conf_file")

    local editor="" dep_dirs_config="" dep_dir dir_cmds cmd_line sync_cats=""
    local has_deps=false
    local _line
    while IFS= read -r _line; do
        case "$_line" in
            editor=*)          editor="${_line#editor=}" ;;
            dep_dirs=*)        dep_dirs_config="${_line#dep_dirs=}" ;;
            sync_categories=*) sync_cats="${_line#sync_categories=}" ;;
        esac
    done <<< "$_conf_content"
    [[ -z "$editor" ]] && editor="code"

    # Editor display name (inline — avoids subshell)
    local ed_name
    case "$editor" in
        cursor)   ed_name="Cursor" ;;
        windsurf) ed_name="Windsurf" ;;
        code)     ed_name="VS Code" ;;
        *)        ed_name="$editor" ;;
    esac

    # Status signalling via temp dir
    local status_dir
    status_dir=$(mktemp -d) || { echo "${_WT_C_RED}Error: mktemp failed${_WT_C_RESET}" >&2; return 1; }
    _wt_init_status_dir="$status_dir"

    # Clean up status_dir if interrupted
    trap 'rm -rf "$status_dir" 2>/dev/null; _wt_init_status_dir=""' INT TERM

    # Collect dep details before forking
    if [[ -n "$dep_dirs_config" ]]; then
        for dep_dir in ${(s:,:)dep_dirs_config}; do
            [[ -z "$dep_dir" ]] && continue
            dir_cmds=$(_wt_detect_install_cmd "$wt_path/$dep_dir")
            [[ -z "$dir_cmds" ]] && continue
            has_deps=true
            cmd_line="${dir_cmds//$'\n'/ && }"
            echo "${dep_dir}|${cmd_line}" >> "$status_dir/meta_dep_details"
        done
    fi

    # Write metadata for display (theme resolved async by Step 2)
    echo "$ed_name" > "$status_dir/meta_editor"
    echo "" > "$status_dir/meta_theme"
    $has_deps && echo 1 > "$status_dir/meta_has_deps" || echo 0 > "$status_dir/meta_has_deps"
    echo "$sync_cats" > "$status_dir/meta_sync_cats"

    # --- Rename workspace files synchronously (before background tasks) ---
    local wt_name=${wt_path:t}
    local git_common_dir
    git_common_dir=$(git -C "$wt_path" rev-parse --git-common-dir 2>/dev/null)
    local ws_file _orig_ws _new_ws
    while IFS= read -r _orig_ws; do
        [[ -z "$_orig_ws" ]] && continue
        _new_ws="${_orig_ws%.code-workspace}.${wt_name}.code-workspace"
        mv "$wt_path/$_orig_ws" "$wt_path/$_new_ws" 2>/dev/null || continue
        # Hide original (now deleted on disk) from git status
        ( cd "$wt_path" && git update-index --skip-worktree "$_orig_ws" 2>/dev/null )
        # Hide renamed (untracked) file via shared exclude
        if [[ -n "$git_common_dir" ]]; then
            mkdir -p "$git_common_dir/info" 2>/dev/null
            echo "$_new_ws" >> "$git_common_dir/info/exclude"
        fi
    done < <(_wt_find_workspace_files "$wt_path")

    # --- Start all steps in parallel ---

    # Step 1: Sync gitignored files
    ( _wt_sync_gitignored "$wt_path" "$main_wt" &>/dev/null; echo $? > "$status_dir/sync" ) &!
    echo $! > "$status_dir/pid_sync"

    # Step 2: Resolve theme (async) + apply + skip-worktree
    (
        local theme
        theme=$(_wt_next_theme "$main_wt")
        echo "$theme" > "$status_dir/meta_theme"
        ws_file=""; settings_dir=""
        while IFS= read -r ws_file; do
            [[ -z "$ws_file" ]] && continue
            _wt_set_theme "$wt_path/$ws_file" "$theme"
        done < <(_wt_find_workspace_files "$wt_path")
        _wt_set_editor_theme "$wt_path" "$theme" "$editor"
        settings_dir=$(_wt_editor_settings_dir "$editor")
        ( cd "$wt_path" && git update-index --skip-worktree "$settings_dir/settings.json" 2>/dev/null )
        echo 0 > "$status_dir/theme"
    ) &!
    echo $! > "$status_dir/pid_theme"

    # Step 3: Install dependencies
    if $has_deps; then
        (
            log_dir="$HOME/.cache/wt"
            mkdir -p "$log_dir"
            bg_pids=(); bg_dirs=(); bg_cmds=()

            for dep_dir in ${(s:,:)dep_dirs_config}; do
                [[ -z "$dep_dir" ]] && continue
                dir_cmds=$(_wt_detect_install_cmd "$wt_path/$dep_dir")
                [[ -z "$dir_cmds" ]] && continue
                cmd_line="${dir_cmds//$'\n'/ && }"
                log_file="$log_dir/${dep_dir//\//-}.log"
                ( cd "$wt_path/$dep_dir" 2>/dev/null && eval "$cmd_line" > "$log_file" 2>&1 ) &
                bg_pids+=($!)
                bg_dirs+=("$dep_dir")
                bg_cmds+=("$cmd_line")
            done

            i=0; exit_code=0; any_failed=0
            for (( i = 1; i <= ${#bg_pids}; i++ )); do
                wait ${bg_pids[$i]}
                exit_code=$?
                if (( exit_code != 0 )); then
                    any_failed=1
                    echo "${bg_dirs[$i]}|${bg_cmds[$i]}|$log_dir/${bg_dirs[$i]//\//-}.log" >> "$status_dir/deps_failures"
                fi
            done
            echo $any_failed > "$status_dir/deps"
        ) &!
        echo $! > "$status_dir/pid_deps"
    fi
}

# ---------------------------------------------------------------------------
# Init status rendering helpers
# ---------------------------------------------------------------------------

# Render the "● configurable via wt init" header block (3 lines).
_wt_render_init_header() {
    printf "\r\033[K\n"
    printf "\r  ${_WT_C_CYAN}●${_WT_C_RESET} ${_WT_C_DIM}configurable via wt init${_WT_C_RESET}\033[K\n"
    printf "\r\033[K\n"
}

# Render branch/sync/theme/deps status lines.
# Mode: "done" (all complete), "spinner" (animating), "background" (disown & exit).
# Reads dep_dd/dep_dc arrays and dep_detail_count from caller scope.
# Args: <mode> <status_dir> <ed_name> <theme> <has_deps_flag> <sync_cat_display> [<frame>]
_wt_render_init_lines() {
    local mode="$1" status_dir="$2" ed_name="$3" theme="$4"
    local has_deps_flag="$5" sync_cat_display="$6" frame="${7:-}"
    local rc ii pid

    # -- Branch --
    if [[ -f "$status_dir/meta_branch_name" ]]; then
        local _br_name=$(<"$status_dir/meta_branch_name")
        if [[ -f "$status_dir/meta_branch_from" ]]; then
            local _br_from=$(<"$status_dir/meta_branch_from")
            local _br_from_color="${_WT_C_CYAN}"
            [[ -f "$status_dir/meta_branch_pr" || -f "$status_dir/meta_branch_remote" ]] && _br_from_color="${_WT_C_YELLOW}"
            _wt_linef ok "Created branch ${_WT_C_YELLOW}${_br_name}${_WT_C_RESET} from ${_br_from_color}${_br_from}${_WT_C_RESET}"
        else
            _wt_linef ok "Created branch ${_WT_C_YELLOW}${_br_name}${_WT_C_RESET}"
        fi
    fi

    # -- Stash --
    if [[ -f "$status_dir/meta_did_stash" ]]; then
        local _stash_result=$(<"$status_dir/meta_did_stash")
        if [[ "$_stash_result" == "ok" ]]; then
            _wt_linef ok "Changes moved to new worktree"
        else
            _wt_linef warn "Stash applied with conflicts — resolve manually in the new worktree"
        fi
    fi

    # -- Sync --
    if [[ "$mode" == "spinner" ]] && ! [[ -f "$status_dir/sync" ]]; then
        if [[ -n "$sync_cat_display" ]]; then
            printf "\r  %s ${_WT_C_DIM}Syncing gitignored${_WT_C_RESET} ${_WT_C_CYAN}%s${_WT_C_RESET} ${_WT_C_DIM}files…${_WT_C_RESET}\033[K\n" "$frame" "$sync_cat_display"
        else
            printf "\r  %s ${_WT_C_DIM}Syncing gitignored files…${_WT_C_RESET}\033[K\n" "$frame"
        fi
    elif [[ "$mode" == "background" ]] && ! [[ -f "$status_dir/sync" ]]; then
        if [[ -n "$sync_cat_display" ]]; then
            _wt_linef skip "Syncing gitignored ${_WT_C_CYAN}${sync_cat_display}${_WT_C_RESET}${_WT_C_DIM} files in background"
        else
            _wt_linef skip "Syncing gitignored files in background"
        fi
        pid=$(<"$status_dir/pid_sync"); disown "$pid" 2>/dev/null
    else
        rc=$(<"$status_dir/sync")
        if [[ "$rc" == "0" && -n "$sync_cat_display" ]]; then
            _wt_linef ok "Synced gitignored ${_WT_C_CYAN}${sync_cat_display}${_WT_C_RESET} files"
        elif [[ "$rc" == "0" ]]; then
            _wt_linef ok "Synced gitignored files"
        else
            _wt_linef skip "No gitignored file sync categories configured"
        fi
    fi

    # -- Theme --
    if [[ "$mode" == "spinner" ]] && ! [[ -f "$status_dir/theme" ]]; then
        printf "\r  %s ${_WT_C_DIM}Setting${_WT_C_RESET} ${_WT_C_CYAN}%s${_WT_C_RESET} ${_WT_C_DIM}theme…${_WT_C_RESET}\033[K\n" "$frame" "$ed_name"
    elif [[ "$mode" == "background" ]] && ! [[ -f "$status_dir/theme" ]]; then
        _wt_linef skip "Setting ${_WT_C_CYAN}${ed_name}${_WT_C_RESET}${_WT_C_DIM} theme in background"
        pid=$(<"$status_dir/pid_theme"); disown "$pid" 2>/dev/null
    else
        local _resolved_theme=$(<"$status_dir/meta_theme")
        _wt_linef ok "${_WT_C_CYAN}${ed_name}${_WT_C_RESET} theme set to ${_WT_C_YELLOW}${_resolved_theme}${_WT_C_RESET}"
    fi

    # -- Deps --
    if (( has_deps_flag )); then
        if [[ "$mode" == "spinner" ]] && ! [[ -f "$status_dir/deps" ]]; then
            printf "\r  %s ${_WT_C_DIM}Installing dependencies…${_WT_C_RESET}\033[K\n" "$frame"
        elif [[ "$mode" == "background" ]] && ! [[ -f "$status_dir/deps" ]]; then
            _wt_linef skip "Installing dependencies in background"
            pid=$(<"$status_dir/pid_deps"); disown "$pid" 2>/dev/null
        else
            rc=$(<"$status_dir/deps")
            [[ "$rc" == "0" ]] \
                && _wt_linef ok "Dependencies installed" \
                || _wt_linef err "Some dependencies failed"
        fi
        local dim=""
        [[ "$mode" == "background" ]] && dim="${_WT_C_DIM}"
        for (( ii = 1; ii <= dep_detail_count; ii++ )); do
            printf "\r      ${dim}${_WT_C_CYAN}%s${_WT_C_RESET} ${_WT_C_DIM}→ %s${_WT_C_RESET}\033[K\n" "${dep_dd[$ii]}" "${dep_dc[$ii]}"
        done
        # Failure details (only in done mode with failures)
        if [[ "$mode" == "done" ]] && [[ -f "$status_dir/deps_failures" ]]; then
            rc=$(<"$status_dir/deps")
            if [[ "$rc" != "0" ]]; then
                local fdir fcmd flog
                while IFS='|' read -r fdir fcmd flog; do
                    printf "\r      ${_WT_C_RED}✗ %s${_WT_C_RESET} ${_WT_C_DIM}(see %s)${_WT_C_RESET}\033[K\n" "$fdir" "$flog"
                done < "$status_dir/deps_failures"
            fi
        fi
    fi
}

# Load init metadata from status_dir into caller-scope variables.
# Sets: ed_name, theme, has_deps_flag, sync_cats, sync_cat_display,
#       dep_detail_count, dep_dd[], dep_dc[]
_wt_load_init_metadata() {
    local status_dir="$1"
    ed_name=$(<"$status_dir/meta_editor")
    theme=$(<"$status_dir/meta_theme")
    has_deps_flag=$(<"$status_dir/meta_has_deps")
    sync_cats=""
    [[ -f "$status_dir/meta_sync_cats" ]] && sync_cats=$(<"$status_dir/meta_sync_cats")
    sync_cat_display="${sync_cats//,/, }"
    dep_detail_count=0
    dep_dd=(); dep_dc=()
    if [[ -f "$status_dir/meta_dep_details" ]]; then
        local ddir dcmd
        while IFS='|' read -r ddir dcmd; do
            dep_dd+=("$ddir"); dep_dc+=("$dcmd")
            dep_detail_count=$(( dep_detail_count + 1 ))
        done < "$status_dir/meta_dep_details"
    fi
}

# Print final init results (used when all tasks completed before await was called)
_wt_await_init_results() {
    local status_dir="$1" ed_name="$2" theme="$3" has_deps_flag="$4"
    local sync_cats sync_cat_display dep_detail_count=0
    local -a dep_dd dep_dc
    _wt_load_init_metadata "$status_dir"

    _wt_render_init_header
    _wt_render_init_lines done "$status_dir" "$ed_name" "$theme" "$has_deps_flag" "$sync_cat_display"
}

# Wait for all init steps with multi-line spinner. User can press enter to background.
# Used for non-interactive paths (--cd, --open, --no-prompt).
# Optional arg: a footer message to display below status lines (e.g. "Opening ... in VS Code…").
_wt_await_init() {
    setopt LOCAL_OPTIONS NO_MONITOR
    [[ -z "$_wt_init_status_dir" || ! -d "$_wt_init_status_dir" ]] && return 0
    local status_dir="$_wt_init_status_dir"
    local footer="${1:-}"

    # Read metadata
    local ed_name theme has_deps_flag sync_cats sync_cat_display dep_detail_count=0
    local -a dep_dd dep_dc
    _wt_load_init_metadata "$status_dir"

    # Check initial state
    local sync_done=false theme_done=false deps_done=false
    [[ -f "$status_dir/sync" ]] && sync_done=true
    [[ -f "$status_dir/theme" ]] && theme_done=true
    if (( ! has_deps_flag )); then deps_done=true
    else [[ -f "$status_dir/deps" ]] && deps_done=true; fi

    # If all done already, just print results and return
    if $sync_done && $theme_done && $deps_done; then
        _wt_await_init_results "$status_dir" "$ed_name" "$theme" "$has_deps_flag"
        rm -rf "$status_dir"
        _wt_init_status_dir=""
        return 0
    fi

    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local fi_=1 key ii
    # Layout: header(3) + status + tail(2) + optional footer(2)
    local header_lines=3
    local status_lines=3
    (( has_deps_flag )) && status_lines=$(( status_lines + 1 + dep_detail_count ))
    [[ -f "$status_dir/meta_did_stash" ]] && status_lines=$(( status_lines + 1 ))
    local tail_lines=2
    local total_lines=$(( header_lines + status_lines + tail_lines ))

    printf '\033[?25l'
    trap 'printf "\033[?25h"' INT TERM
    for (( ii = 1; ii <= total_lines; ii++ )); do printf "\033[K\n"; done

    while true; do
        if read -rsk 1 -t 0.08 key 2>/dev/null; then
            case "$key" in
                $'\033')
                    # Drain any remaining escape sequence bytes (e.g. arrow keys send \033[A)
                    while read -rsk 1 -t 0.05 _ 2>/dev/null; do :; done
                    ;&
                $'\n'|$'\r'|'')
                    printf "\033[${total_lines}A"
                    _wt_render_init_header
                    _wt_render_init_lines background "$status_dir" "$ed_name" "$theme" "$has_deps_flag" "$sync_cat_display"
                    if [[ -n "$footer" ]]; then
                        printf "\r\033[K\n"
                        printf "\r  ${_WT_C_CYAN}${_WT_C_BOLD}→ %s${_WT_C_RESET}\033[K\n" "$footer"
                    fi
                    printf "\033[J"
                    printf '\033[?25h'
                    _wt_init_status_dir=""
                    return 0
                    ;;
            esac
        fi

        fi_=$(( fi_ % ${#frames} + 1 ))
        ! $sync_done  && [[ -f "$status_dir/sync"  ]] && sync_done=true
        ! $theme_done && [[ -f "$status_dir/theme" ]] && theme_done=true
        ! $deps_done && (( has_deps_flag )) && [[ -f "$status_dir/deps" ]] && deps_done=true

        printf "\033[${total_lines}A"
        _wt_render_init_header
        _wt_render_init_lines spinner "$status_dir" "$ed_name" "$theme" "$has_deps_flag" "$sync_cat_display" "${frames[$fi_]}"
        if [[ -n "$footer" ]]; then
            printf "\r\033[K\n"
            printf "\r  ${_WT_C_CYAN}${_WT_C_BOLD}→ %s${_WT_C_RESET}  ${_WT_C_DIM}press enter to move to background${_WT_C_RESET}\033[K\n" "$footer"
        else
            printf "\r\033[K\n"
            printf "\r  ${_WT_C_DIM}press enter to move to background${_WT_C_RESET}\033[K\n"
        fi

        $sync_done && $theme_done && $deps_done && break
    done

    # All completed naturally — render final state
    printf "\033[${total_lines}A"
    _wt_render_init_header
    _wt_render_init_lines done "$status_dir" "$ed_name" "$theme" "$has_deps_flag" "$sync_cat_display"
    if [[ -n "$footer" ]]; then
        printf "\r\033[K\n"
        printf "\r  ${_WT_C_CYAN}${_WT_C_BOLD}→ %s${_WT_C_RESET}\033[K\n" "$footer"
    fi
    printf "\033[J"
    printf '\033[?25h'
    rm -rf "$status_dir"
    _wt_init_status_dir=""
    return 0
}

# Combined init status display + "What next?" picker.
# Renders all init tasks with live spinners alongside an interactive picker.
# After the user selects, freezes the display and executes the chosen action.
# If init tasks are still running, shows a dimmed background prompt that
# updates in place with confirmation.
_wt_init_prompt() {
    setopt LOCAL_OPTIONS NO_MONITOR
    local wt_path="$1" editor_override="$2" preselected_action="${3:-}" preselected_reason="${4:-}"
    local status_dir="$_wt_init_status_dir"
    [[ -z "$status_dir" || ! -d "$status_dir" ]] && return 1

    # Metadata
    local ed_name theme has_deps_flag sync_cats sync_cat_display dep_detail_count=0
    local -a dep_dd dep_dc
    _wt_load_init_metadata "$status_dir"

    # Picker setup
    local editor ed_label
    editor="${editor_override:-$(_wt_config_get editor)}"
    editor="${editor:-code}"
    ed_label=$(_wt_editor_name "$editor")
    local -a opt_labels=("Open in $ed_label" "cd into worktree" "Do nothing")
    local num_opts=${#opt_labels}

    # Pre-load workspaces for potential sub-picker
    _wt_resolve_workspaces "$wt_path"
    local -a _ip_workspaces=("${reply[@]}")
    local _ip_root_ws=""
    local -a _ip_nested_ws
    for ws in "${_ip_workspaces[@]}"; do
        if [[ "$(dirname "$ws")" == "." ]]; then
            _ip_root_ws="$ws"
        else
            _ip_nested_ws+=("$ws")
        fi
    done
    local _ip_has_multi_ws=false
    (( ${#_ip_workspaces} > 1 )) && _ip_has_multi_ws=true

    # Build workspace picker labels (used if transitioning to sub-picker)
    local -a _ip_ws_labels=() _ip_ws_keys=()
    if $_ip_has_multi_ws; then
        if [[ -n "$_ip_root_ws" ]]; then
            local _ip_root_label="${_ip_root_ws%.code-workspace}"
            _ip_ws_labels+=("$_ip_root_label ${_WT_C_DIM}(root)${_WT_C_RESET}")
            _ip_ws_keys+=("$_ip_root_ws")
        else
            _ip_ws_labels+=("Worktree root ${_WT_C_DIM}($(basename "$wt_path"))${_WT_C_RESET}")
            _ip_ws_keys+=(".")
        fi
        for ws in "${_ip_nested_ws[@]}"; do
            _ip_ws_labels+=("${ws%.code-workspace}")
            _ip_ws_keys+=("$ws")
        done
    fi

    # Check default_workspace config to skip the sub-picker
    local _ip_default_ws_idx=0
    if $_ip_has_multi_ws; then
        local _ip_dw_config
        _ip_dw_config=$(_wt_config_get default_workspace 2>/dev/null) || _ip_dw_config=""
        if [[ -n "$_ip_dw_config" && "$_ip_dw_config" != "ask" ]]; then
            local _ip_wt_name=$(basename "$wt_path")
            for (( _dwi = 1; _dwi <= ${#_ip_ws_keys}; _dwi++ )); do
                if [[ "${_ip_ws_keys[$_dwi]}" == "$_ip_dw_config" ]]; then
                    _ip_default_ws_idx=$_dwi
                    _ip_has_multi_ws=false
                    break
                fi
                # Check pre-rename form
                local _ip_orig="${_ip_ws_keys[$_dwi]%.${_ip_wt_name}.code-workspace}.code-workspace"
                if [[ "$_ip_orig" == "$_ip_dw_config" ]]; then
                    _ip_default_ws_idx=$_dwi
                    _ip_has_multi_ws=false
                    break
                fi
            done
        fi
    fi
    local _ws_reason_suffix=""
    (( _ip_default_ws_idx > 0 )) && _ws_reason_suffix=" ${_WT_C_DIM}(configured by wt init)${_WT_C_RESET}"

    # Task state
    local sync_done=false theme_done=false deps_done=false all_done=false
    [[ -f "$status_dir/theme" ]] && theme_done=true
    if (( ! has_deps_flag )); then deps_done=true
    else [[ -f "$status_dir/deps" ]] && deps_done=true; fi
    $sync_done && $theme_done && $deps_done && all_done=true

    # Layout: header(3) + status + tail
    local header_lines=3
    local status_lines=3
    (( has_deps_flag )) && status_lines=$(( status_lines + 1 + dep_detail_count ))
    [[ -f "$status_dir/meta_did_stash" ]] && status_lines=$(( status_lines + 1 ))
    local tail_lines=$(( 1 + 1 + num_opts ))
    local total_lines=$(( header_lines + status_lines + tail_lines ))

    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local fi_=1 key sel=1 choice=-1 ws_choice=-1 ii
    local picker_phase=1  # 1 = "What next?", 2 = workspace sub-picker

    # Current picker state (swapped when transitioning to workspace sub-picker)
    local -a _cur_labels=("${opt_labels[@]}")
    local _cur_num=$num_opts
    local _cur_heading="What next?"
    # Frozen "What next?" lines to render above the workspace sub-picker
    local _frozen_lines=""
    local _reason_suffix=""
    [[ -n "$preselected_reason" ]] && _reason_suffix=" ${_WT_C_DIM}(${preselected_reason})${_WT_C_RESET}"

    # Handle preselected action: skip "What next?" picker, go straight to action
    if [[ -n "$preselected_action" ]]; then
        choice=$preselected_action
        # Build compact frozen "What next?" line
        _frozen_lines="\r\033[K\n\r${_WT_C_BOLD}What next?${_WT_C_RESET} ${_WT_C_CYAN}${_WT_C_BOLD}› ${opt_labels[$choice]}${_WT_C_RESET}${_reason_suffix}\033[K\n"
        tail_lines=2
        if (( choice == 1 || choice == 2 )) && $_ip_has_multi_ws; then
            # Need workspace sub-picker — enter phase 2
            picker_phase=2
            _cur_labels=("${_ip_ws_labels[@]}")
            _cur_num=${#_ip_ws_labels}
            if (( choice == 1 )); then
                _cur_heading="Open workspace:"
            else
                _cur_heading="cd to:"
            fi
            sel=1
            tail_lines=$(( 2 + 1 + _cur_num ))
        elif (( choice == 1 || choice == 2 )) && (( _ip_default_ws_idx > 0 )); then
            # Default workspace configured — show compact frozen sub-picker
            picker_phase=2
            ws_choice=$(( _ip_default_ws_idx - 1 ))
            _cur_labels=("${_ip_ws_labels[@]}")
            _cur_num=${#_ip_ws_labels}
            if (( choice == 1 )); then
                _cur_heading="Open workspace:"
            else
                _cur_heading="cd to:"
            fi
            tail_lines=3
        fi
        total_lines=$(( header_lines + status_lines + tail_lines ))
    fi

    printf '\033[?25l'
    trap 'printf "\033[?25h"' INT TERM
    for (( ii = 1; ii <= total_lines; ii++ )); do printf "\n"; done

    # When everything is preselected (no interaction needed), skip input after first render
    local _preselected_no_picker=false
    if [[ -n "$preselected_action" ]]; then
        # Skip if: action is "Do nothing", or action needs no ws picker, or ws is also preselected
        if (( picker_phase == 1 )) || (( ws_choice >= 0 )); then
            _preselected_no_picker=true
        fi
    fi

    # ── Picker loop: Status + Picker (with optional sub-picker) ──
    while true; do
        if $_preselected_no_picker; then
            : # Skip input — will break after rendering
        elif read -rsk 1 -t 0.08 key 2>/dev/null; then
            case "$key" in
                $'\033')
                    if read -rsk 1 -t 0.05 key 2>/dev/null && [[ "$key" == "[" ]]; then
                        read -rsk 1 -t 0.05 key 2>/dev/null
                        case "$key" in
                            A) sel=$(( sel > 1 ? sel - 1 : _cur_num )) ;;
                            B) sel=$(( sel < _cur_num ? sel + 1 : 1 )) ;;
                        esac
                    else
                        # Bare Escape — "Do nothing" / cancel
                        if (( picker_phase == 1 )); then
                            choice=$num_opts; break
                        else
                            ws_choice=255; break
                        fi
                    fi
                    ;;
                $'\n'|$'\r'|'')
                    if (( picker_phase == 1 )); then
                        choice=$sel
                        # Check if we need a workspace sub-picker
                        if (( choice == 1 || choice == 2 )) && $_ip_has_multi_ws; then
                            # Freeze "What next?" as compact single line
                            _frozen_lines="\r\033[K\n\r${_WT_C_BOLD}What next?${_WT_C_RESET} ${_WT_C_CYAN}${_WT_C_BOLD}› ${opt_labels[$choice]}${_WT_C_RESET}\033[K\n"
                            # Transition to workspace sub-picker
                            picker_phase=2
                            _cur_labels=("${_ip_ws_labels[@]}")
                            _cur_num=${#_ip_ws_labels}
                            if (( choice == 1 )); then
                                _cur_heading="Open workspace:"
                            else
                                _cur_heading="cd to:"
                            fi
                            sel=1
                            # Expand rendering area for the sub-picker lines
                            local _old_tail=$tail_lines
                            tail_lines=$(( 2 + 1 + _cur_num ))
                            total_lines=$(( header_lines + status_lines + tail_lines ))
                            local _extra_lines=$(( tail_lines - _old_tail ))
                            for (( ii = 1; ii <= _extra_lines; ii++ )); do printf "\n"; done
                            continue
                        elif (( choice == 1 || choice == 2 )) && (( _ip_default_ws_idx > 0 )); then
                            # Default workspace — freeze "What next?" as compact single line, then break
                            _frozen_lines="\r\033[K\n\r${_WT_C_BOLD}What next?${_WT_C_RESET} ${_WT_C_CYAN}${_WT_C_BOLD}› ${opt_labels[$choice]}${_WT_C_RESET}\033[K\n"
                            picker_phase=2
                            ws_choice=$(( _ip_default_ws_idx - 1 ))
                            _cur_labels=("${_ip_ws_labels[@]}")
                            _cur_num=${#_ip_ws_labels}
                            if (( choice == 1 )); then
                                _cur_heading="Open workspace:"
                            else
                                _cur_heading="cd to:"
                            fi
                            # Expand rendering area
                            local _old_tail2=$tail_lines
                            tail_lines=$(( 2 + 1 + _cur_num ))
                            total_lines=$(( header_lines + status_lines + tail_lines ))
                            local _extra_lines2=$(( tail_lines - _old_tail2 ))
                            for (( ii = 1; ii <= _extra_lines2; ii++ )); do printf "\n"; done
                            break
                        else
                            break
                        fi
                    else
                        ws_choice=$(( sel - 1 )); break
                    fi
                    ;;
            esac
        fi

        fi_=$(( fi_ % ${#frames} + 1 ))
        ! $sync_done  && [[ -f "$status_dir/sync"  ]] && sync_done=true
        ! $theme_done && [[ -f "$status_dir/theme" ]] && theme_done=true
        ! $deps_done && (( has_deps_flag )) && [[ -f "$status_dir/deps" ]] && deps_done=true
        $sync_done && $theme_done && $deps_done && all_done=true

        printf "\033[${total_lines}A"
        _wt_render_init_header
        _wt_render_init_lines spinner "$status_dir" "$ed_name" "$theme" "$has_deps_flag" "$sync_cat_display" "${frames[$fi_]}"

        if $_preselected_no_picker; then
            # Preselected action — render compact frozen state and break
            printf '%b' "$_frozen_lines"
            if (( picker_phase == 2 )); then
                # Compact frozen workspace line
                printf "\r${_WT_C_BOLD}${_cur_heading}${_WT_C_RESET} ${_WT_C_CYAN}${_WT_C_BOLD}› %s${_WT_C_RESET}%b\033[K\n" "${_cur_labels[$(( ws_choice + 1 ))]}" "$_ws_reason_suffix"
            fi
            break
        elif (( picker_phase == 1 )); then
            # Render "What next?" picker
            printf "\r\033[K\n"
            printf "\r${_WT_C_BOLD}${_cur_heading}${_WT_C_RESET}\033[K\n"
            for (( ii = 1; ii <= _cur_num; ii++ )); do
                if (( ii == sel )); then
                    printf "\r  ${_WT_C_CYAN}${_WT_C_BOLD}› %s${_WT_C_RESET}\033[K\n" "${_cur_labels[$ii]}"
                else
                    printf "\r  ${_WT_C_DIM}  %s${_WT_C_RESET}\033[K\n" "${_cur_labels[$ii]}"
                fi
            done
        else
            # Render frozen "What next?" + workspace sub-picker
            printf '%b' "$_frozen_lines"
            printf "\r${_WT_C_BOLD}${_cur_heading}${_WT_C_RESET}\033[K\n"
            for (( ii = 1; ii <= _cur_num; ii++ )); do
                if (( ii == sel )); then
                    printf "\r  ${_WT_C_CYAN}${_WT_C_BOLD}› %s${_WT_C_RESET}\033[K\n" "${_cur_labels[$ii]}"
                else
                    printf "\r  ${_WT_C_DIM}  %s${_WT_C_RESET}\033[K\n" "${_cur_labels[$ii]}"
                fi
            done
        fi
    done

    # ── Render final selected state ──────────────────────────────
    ! $sync_done  && [[ -f "$status_dir/sync"  ]] && sync_done=true
    ! $theme_done && [[ -f "$status_dir/theme" ]] && theme_done=true
    ! $deps_done && (( has_deps_flag )) && [[ -f "$status_dir/deps" ]] && deps_done=true
    $sync_done && $theme_done && $deps_done && all_done=true

    printf "\033[${total_lines}A"
    _wt_render_init_header
    if $all_done; then
        _wt_render_init_lines done "$status_dir" "$ed_name" "$theme" "$has_deps_flag" "$sync_cat_display"
    else
        _wt_render_init_lines spinner "$status_dir" "$ed_name" "$theme" "$has_deps_flag" "$sync_cat_display" "${frames[$fi_]}"
    fi

    if [[ -n "$preselected_action" ]]; then
        # Compact preselected render
        printf '%b' "$_frozen_lines"
        if (( picker_phase == 2 )); then
            printf "\r${_WT_C_BOLD}${_cur_heading}${_WT_C_RESET} ${_WT_C_CYAN}${_WT_C_BOLD}› %s${_WT_C_RESET}%b\033[K\n" "${_cur_labels[$(( ws_choice + 1 ))]}" "$_ws_reason_suffix"
            tail_lines=3
        else
            tail_lines=2
        fi
    elif (( picker_phase == 2 )); then
        # Render frozen "What next?" + selected workspace (compact)
        printf '%b' "$_frozen_lines"
        printf "\r${_WT_C_BOLD}${_cur_heading}${_WT_C_RESET} ${_WT_C_CYAN}${_WT_C_BOLD}› %s${_WT_C_RESET}%b\033[K\n" "${_cur_labels[$(( ws_choice + 1 ))]}" "$_ws_reason_suffix"
        tail_lines=3
    else
        printf "\r\033[K\n"
        printf "\r${_WT_C_BOLD}What next?${_WT_C_RESET}\033[K\n"
        for (( ii = 1; ii <= num_opts; ii++ )); do
            if (( ii == choice )); then
                printf "\r  ${_WT_C_CYAN}${_WT_C_BOLD}› %s${_WT_C_RESET}\033[K\n" "${opt_labels[$ii]}"
            else
                printf "\r  ${_WT_C_DIM}  %s${_WT_C_RESET}\033[K\n" "${opt_labels[$ii]}"
            fi
        done
    fi
    printf "\033[J"
    printf '\033[?25h'
    trap - INT TERM

    # ── Execute chosen action ────────────────────────────────────
    case $choice in
        1)
            if (( ws_choice == 255 )); then
                : # Cancelled
            elif $_ip_has_multi_ws && (( ws_choice >= 0 )); then
                # Open the selected workspace
                local _ws_key="${_ip_ws_keys[$(( ws_choice + 1 ))]}"
                if [[ "$_ws_key" == "." ]]; then
                    "$editor" -n "$wt_path"
                else
                    "$editor" -n "$wt_path/$_ws_key"
                fi
            elif (( _ip_default_ws_idx > 0 )); then
                # Default workspace configured — use it directly
                local _ws_key="${_ip_ws_keys[$_ip_default_ws_idx]}"
                if [[ "$_ws_key" == "." ]]; then
                    "$editor" -n "$wt_path"
                else
                    "$editor" -n "$wt_path/$_ws_key"
                fi
            else
                # Single/no workspace — auto-select
                local ws_file
                ws_file=$(_wt_detect_workspace "$wt_path" "$PWD") || ws_file=""
                if [[ -n "$ws_file" ]]; then
                    "$editor" -n "$wt_path/$ws_file"
                else
                    "$editor" -n "$wt_path"
                fi
            fi
            ;;
        2)
            if (( ws_choice == 255 )); then
                : # Cancelled
            elif $_ip_has_multi_ws && (( ws_choice >= 0 )); then
                # cd to the selected workspace directory
                local _ws_key="${_ip_ws_keys[$(( ws_choice + 1 ))]}"
                if [[ "$_ws_key" == "." ]]; then
                    cd "$wt_path"
                else
                    cd "$wt_path/$(dirname "$_ws_key")"
                fi
            elif (( _ip_default_ws_idx > 0 )); then
                # Default workspace configured — use it directly
                local _ws_key="${_ip_ws_keys[$_ip_default_ws_idx]}"
                if [[ "$_ws_key" == "." ]]; then
                    cd "$wt_path"
                else
                    cd "$wt_path/$(dirname "$_ws_key")"
                fi
            else
                cd "$(_wt_equiv_dir "$wt_path" "$PWD")"
            fi
            ;;
        3) ;;
    esac

    # ── Background prompt (if init tasks still running) ──────────
    ! $sync_done  && [[ -f "$status_dir/sync"  ]] && sync_done=true
    ! $theme_done && [[ -f "$status_dir/theme" ]] && theme_done=true
    ! $deps_done && (( has_deps_flag )) && [[ -f "$status_dir/deps" ]] && deps_done=true
    $sync_done && $theme_done && $deps_done && all_done=true

    if $all_done; then
        rm -rf "$status_dir"
        _wt_init_status_dir=""
    else
        echo ""
        # Offsets for cursor travel: prompt line ↔ start of status lines
        local _up_to_status=$(( 1 + status_lines + tail_lines ))
        local _down_to_prompt=$(( 1 + tail_lines ))

        printf '\033[?25l'
        trap 'printf "\033[?25h"' INT TERM
        while true; do
            if read -rsk 1 -t 0.08 key 2>/dev/null; then
                case "$key" in
                    $'\033')
                        while read -rsk 1 -t 0.05 _ 2>/dev/null; do :; done
                        ;&
                    $'\n'|$'\r'|'')
                        # Final render: mark running items as backgrounded
                        printf "\033[${_up_to_status}A"
                        _wt_render_init_lines background "$status_dir" "$ed_name" "$theme" "$has_deps_flag" "$sync_cat_display"
                        printf "\033[${_down_to_prompt}B"
                        printf "\r  ${_WT_C_DIM}↳ Setup tasks moved to background${_WT_C_RESET}\033[K\n"
                        printf '\033[?25h'
                        trap - INT TERM
                        _wt_init_status_dir=""
                        return 0
                        ;;
                esac
            fi

            fi_=$(( fi_ % ${#frames} + 1 ))
            ! $sync_done  && [[ -f "$status_dir/sync"  ]] && sync_done=true
            ! $theme_done && [[ -f "$status_dir/theme" ]] && theme_done=true
            ! $deps_done && (( has_deps_flag )) && [[ -f "$status_dir/deps" ]] && deps_done=true
            if $sync_done && $theme_done && $deps_done; then
                # All done — final render with checkmarks
                printf "\033[${_up_to_status}A"
                _wt_render_init_lines done "$status_dir" "$ed_name" "$theme" "$has_deps_flag" "$sync_cat_display"
                printf "\033[${_down_to_prompt}B"
                printf "\r  ${_WT_C_DIM}✓ Setup tasks complete${_WT_C_RESET}\033[K\n"
                printf '\033[?25h'
                trap - INT TERM
                rm -rf "$status_dir"
                _wt_init_status_dir=""
                return 0
            fi

            # Animate: re-render status lines with live spinner, then prompt
            printf "\033[${_up_to_status}A"
            _wt_render_init_lines spinner "$status_dir" "$ed_name" "$theme" "$has_deps_flag" "$sync_cat_display" "${frames[$fi_]}"
            printf "\033[${_down_to_prompt}B"
            printf "\r  ${frames[$fi_]} ${_WT_C_DIM}Setup tasks running — press enter to move to background${_WT_C_RESET}\033[K\n\033[K\033[1A"
        done
    fi
}

# ---------------------------------------------------------------------------
# Execute helpers
# ---------------------------------------------------------------------------

_wt_run_execute() {
    local cmd="$1"
    [[ -z "$cmd" ]] && return
    eval "$cmd"
}

_wt_skip_execute() {
    local cmd="$1"
    [[ -z "$cmd" ]] && return
    _wt_line warn "--execute skipped (only runs with --cd)"
}

# ---------------------------------------------------------------------------
# Subcommands
# ---------------------------------------------------------------------------

_wt_cmd_create() {
    local name=""
    local start_ref=""
    local editor_override=""
    local flag_cd=false
    local flag_open=false
    local flag_no_prompt=false
    local flag_no_init=false
    local flag_configure=false
    local flag_stash=false
    local pr_number=""
    local branch_name=""
    local execute_cmd=""

    # Expand combined short flags (e.g. -osc → -o -s -c)
    local _expanded_args=()
    for _arg in "$@"; do
        if [[ "$_arg" =~ ^-[a-zA-Z]{2,}$ ]]; then
            local _chars="${_arg#-}"
            local _i
            for (( _i=0; _i < ${#_chars}; _i++ )); do
                _expanded_args+=("-${_chars[$_i+1]}")
            done
        else
            _expanded_args+=("$_arg")
        fi
    done
    set -- "${_expanded_args[@]}"

    while (( $# > 0 )); do
        case "$1" in
            --from|-f)
                start_ref="$2"
                shift 2
                ;;
            --pr|-p)
                pr_number="$2"
                shift 2
                ;;
            --checkout|-c)
                branch_name="$2"
                shift 2
                ;;
            --editor|-e)
                editor_override="$2"
                shift 2
                ;;
            --cd|-d)
                flag_cd=true
                shift
                ;;
            --open|-o)
                flag_open=true
                shift
                ;;
            --no-prompt|-n)
                flag_no_prompt=true
                shift
                ;;
            --no-init|-N)
                flag_no_init=true
                shift
                ;;
            --configure|-C)
                flag_configure=true
                shift
                ;;
            --stash|-s)
                flag_stash=true
                shift
                ;;
            --execute|-x)
                execute_cmd="$2"
                shift 2
                ;;
            -*)
                echo "${_WT_C_RED}Unknown flag: $1${_WT_C_RESET}" >&2
                return 1
                ;;
            *)
                if [[ -z "$name" ]]; then
                    name="$1"
                else
                    echo "${_WT_C_RED}Unexpected argument: $1${_WT_C_RESET}" >&2
                    return 1
                fi
                shift
                ;;
        esac
    done

    # --pr, --checkout, and --from are mutually exclusive
    local _exclusive_count=0
    [[ -n "$pr_number" ]] && (( _exclusive_count++ ))
    [[ -n "$branch_name" ]] && (( _exclusive_count++ ))
    [[ -n "$start_ref" ]] && (( _exclusive_count++ ))
    if (( _exclusive_count > 1 )); then
        echo "${_WT_C_RED}--pr, --checkout, and --from are mutually exclusive.${_WT_C_RESET}" >&2
        return 1
    fi

    _wt_ensure_setup || return 1

    if $flag_configure; then
        _wt_config_transient=true
        _wt_config_overrides=()
        _wt_cmd_init || { _wt_config_transient=false; _wt_config_overrides=(); return 1; }
    fi

    # Wrap in always block so transient config overrides are cleaned up on any exit
    {

    local repo_root
    repo_root=$(_wt_repo_root) || return 1
    local main_wt
    main_wt=$(_wt_main_worktree)
    local parent
    parent=$(_wt_worktree_parent) || parent=$(dirname "$main_wt")

    if [[ -z "$name" ]]; then
        name=$(_wt_next_name "$main_wt")
    fi

    # Validate worktree name
    if [[ "$name" == -* ]]; then
        echo "${_WT_C_RED}Invalid name: cannot start with '-'${_WT_C_RESET}" >&2
        return 1
    fi
    if [[ "$name" == *..* ]]; then
        echo "${_WT_C_RED}Invalid name: cannot contain '..'${_WT_C_RESET}" >&2
        return 1
    fi
    if [[ "$name" == *[^a-zA-Z0-9._/-]* ]]; then
        echo "${_WT_C_RED}Invalid name: only alphanumeric characters, dots, slashes, hyphens, and underscores are allowed${_WT_C_RESET}" >&2
        return 1
    fi

    local wt_path="$parent/$name"

    if [[ -d "$wt_path" ]]; then
        echo "${_WT_C_RED}Directory already exists:${_WT_C_RESET} $wt_path" >&2
        return 1
    fi

    local default_branch=$(_wt_default_branch "$main_wt")

    # Resolve starting point for the new branch
    local branch_start
    branch_start=$(_wt_config_get branch_start 2>/dev/null) || branch_start="main"

    local base_ref=""
    if [[ -n "$start_ref" ]]; then
        # --from overrides the configured starting point
        base_ref="$start_ref"
    elif [[ "$branch_start" == "main" ]]; then
        base_ref="$default_branch"
    else
        # Custom branch name (e.g. "develop")
        base_ref="$branch_start"
    fi

    local branch_tool
    branch_tool=$(_wt_config_get branch_tool 2>/dev/null) || branch_tool="git"

    # --- Handle --pr: fetch PR branch from GitHub ---
    local pr_branch="" pr_is_fork=false
    if [[ -n "$pr_number" ]]; then
        if ! command -v gh &>/dev/null; then
            echo "${_WT_C_RED}gh CLI is required for --pr. Install it from https://cli.github.com${_WT_C_RESET}" >&2
            return 1
        fi

        echo ""
        _wt_heading "Fetching PR ${_WT_C_YELLOW}#${pr_number}…"

        local pr_json
        if ! pr_json=$(gh pr view "$pr_number" --json headRefName,headRepositoryOwner,isCrossRepository 2>&1); then
            echo "${_WT_C_RED}Failed to fetch PR #${pr_number}: ${pr_json}${_WT_C_RESET}" >&2
            return 1
        fi

        # Parse PR branch and cross-repository status in a single python3 call
        local is_cross
        read -r pr_branch is_cross <<< "$(echo "$pr_json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['headRefName'], d.get('isCrossRepository', False))" 2>/dev/null)"

        if [[ -z "$pr_branch" ]]; then
            echo "${_WT_C_RED}Could not determine PR branch name.${_WT_C_RESET}" >&2
            return 1
        fi

        # Use PR branch name as worktree name if no name given
        if [[ "$name" == "$(_wt_next_name "$main_wt")" ]]; then
            # Name was auto-generated — use sanitized PR branch instead
            local sanitized="${pr_branch//\//-}"
            sanitized="${sanitized//[^a-zA-Z0-9._-]/-}"
            name="$sanitized"
            wt_path="$parent/$name"
            if [[ -d "$wt_path" ]]; then
                echo "${_WT_C_RED}Directory already exists:${_WT_C_RESET} $wt_path" >&2
                return 1
            fi
        fi

        # Fetch the PR branch
        local fetch_output fetch_rc=0
        if [[ "$is_cross" == "True" ]]; then
            pr_is_fork=true
            fetch_output=$(git -C "$main_wt" fetch origin "pull/${pr_number}/head:${pr_branch}" 2>&1) || fetch_rc=$?
        else
            fetch_output=$(git -C "$main_wt" fetch origin "${pr_branch}" 2>&1) || fetch_rc=$?
            if (( fetch_rc == 0 )); then
                # Ensure local branch exists tracking the remote
                if ! git -C "$main_wt" rev-parse --verify "refs/heads/${pr_branch}" &>/dev/null; then
                    git -C "$main_wt" branch "$pr_branch" "origin/${pr_branch}" &>/dev/null
                fi
            fi
        fi
        if (( fetch_rc != 0 )); then
            echo "${_WT_C_RED}Failed to fetch PR branch: ${fetch_output}${_WT_C_RESET}" >&2
            return 1
        fi
    fi

    # --- Handle --checkout: check out an existing branch (local first, then origin) ---
    local explicit_branch=""
    if [[ -n "$branch_name" ]]; then
        if git -C "$main_wt" rev-parse --verify "refs/heads/${branch_name}" &>/dev/null; then
            # Branch exists locally — use it directly
            echo ""
            _wt_heading "Using local branch ${_WT_C_YELLOW}${branch_name}"
        else
            # Not local — try fetching from origin
            echo ""
            _wt_heading "Fetching branch ${_WT_C_YELLOW}${branch_name}${_WT_C_RESET} from origin…"

            local fetch_output
            if ! fetch_output=$(git -C "$main_wt" fetch origin "${branch_name}" 2>&1); then
                echo "${_WT_C_RED}Branch '${branch_name}' not found locally or on origin: ${fetch_output}${_WT_C_RESET}" >&2
                return 1
            fi

            # Create a local branch tracking the remote
            git -C "$main_wt" branch "$branch_name" "origin/${branch_name}" &>/dev/null
        fi

        explicit_branch="$branch_name"

        # Use branch name as worktree name if no name given
        if [[ "$name" == "$(_wt_next_name "$main_wt")" ]]; then
            local sanitized="${branch_name//\//-}"
            sanitized="${sanitized//[^a-zA-Z0-9._-]/-}"
            name="$sanitized"
            wt_path="$parent/$name"
            if [[ -d "$wt_path" ]]; then
                echo "${_WT_C_RED}Directory already exists:${_WT_C_RESET} $wt_path" >&2
                return 1
            fi
        fi
    fi

    # Detect uncommitted changes and offer to stash
    local did_stash=false
    local _stash_changes
    _stash_changes=$(git status --porcelain 2>/dev/null)
    if [[ -n "$_stash_changes" ]]; then
        if $flag_stash; then
            # Auto-stash without prompting
            local _stash_output
            _stash_output=$(git stash push --include-untracked -m "wt: stash for $name" 2>&1)
            if (( $? != 0 )); then
                echo "${_WT_C_RED}Failed to stash changes: ${_stash_output}${_WT_C_RESET}" >&2
                return 1
            fi
            did_stash=true
        else
            # Prompt the user
            echo ""
            echo "  ${_WT_C_YELLOW}You have uncommitted changes in the current worktree.${_WT_C_RESET}"
            echo ""
            _wt_pick \
                "y" "Yes — stash changes and apply to new worktree" \
                "n" "No — leave changes here"
            local _stash_choice=$?
            if (( _stash_choice == 0 )); then
                local _stash_output
                _stash_output=$(git stash push --include-untracked -m "wt: stash for $name" 2>&1)
                if (( $? != 0 )); then
                    echo "${_WT_C_RED}Failed to stash changes: ${_stash_output}${_WT_C_RESET}" >&2
                    return 1
                fi
                did_stash=true
            fi
        fi
    elif $flag_stash; then
        _wt_line warn "No uncommitted changes to stash"
    fi

    echo ""
    _wt_heading "Creating worktree ${_WT_C_YELLOW}$name"

    local -a git_args
    if [[ -n "$pr_branch" ]]; then
        # PR mode: check out the fetched branch directly
        git_args=(worktree add "$wt_path" "$pr_branch")
    elif [[ -n "$explicit_branch" ]]; then
        # Branch mode: check out the fetched branch directly
        git_args=(worktree add "$wt_path" "$explicit_branch")
    else
        git_args=(worktree add "$wt_path" -b "$name" $base_ref)
    fi

    local git_output
    git_output=$(git -C "$main_wt" "${git_args[@]}" 2>&1)
    local git_rc=$?
    if (( git_rc != 0 )); then
        if [[ "$git_output" == *"already exists"* ]]; then
            echo ""
            echo "  ${_WT_C_YELLOW}Branch ${_WT_C_CYAN}$name${_WT_C_YELLOW} already exists.${_WT_C_RESET} Choose a different worktree name."
            return 1
        elif [[ "$git_output" == *"already used by worktree"* || "$git_output" == *"already checked out"* ]]; then
            local _err_ref="${base_ref:-HEAD}"
            echo ""
            echo "  ${_WT_C_YELLOW}${_err_ref}${_WT_C_RESET} is already checked out by another worktree."
            echo ""

            local -a _rl _rv _rk
            _rk=("d"); _rl=("Check out ${_WT_C_CYAN}${_err_ref}${_WT_C_RESET} ${_WT_C_DIM}(detached)${_WT_C_RESET}")
            _rv=("Check out $_err_ref (detached)")
            _rk+=("c"); _rl+=("Cancel"); _rv+=("Cancel")

            local _rmax=0 _ri
            for _ri in "${_rv[@]}"; do (( ${#_ri} > _rmax )) && _rmax=${#_ri}; done
            for (( _ri = 1; _ri <= ${#_rl}; _ri++ )); do
                _rl[$_ri]="${_rl[$_ri]}$(printf '%*s' $(( _rmax - ${#_rv[$_ri]} )) '')"
            done

            local -a _pick_args
            for (( _ri = 1; _ri <= ${#_rk}; _ri++ )); do
                _pick_args+=("${_rk[$_ri]}" "${_rl[$_ri]}")
            done
            _wt_pick "${_pick_args[@]}"
            local _recover_choice=$?

            local _action="cancel"
            if (( _recover_choice < 255 )); then
                _action="${_rk[$(( _recover_choice + 1 ))]}"
            fi
            case "$_action" in
                d)
                    git_args=(worktree add --detach "$wt_path" "${_err_ref}")
                    ;;
                *)
                    return 1
                    ;;
            esac
            git_output=$(git -C "$main_wt" "${git_args[@]}" 2>&1)
            git_rc=$?
            if (( git_rc != 0 )); then
                echo "${_WT_C_RED}${git_output}${_WT_C_RESET}" >&2
                return 1
            fi
        else
            echo "${_WT_C_RED}${git_output}${_WT_C_RESET}" >&2
            return 1
        fi
    fi

    # Graphite: track the new branch in Graphite's stack
    if [[ "$branch_tool" == "graphite" ]]; then
        local gt_output
        gt_output=$(cd "$wt_path" && gt track --parent "${base_ref:-$default_branch}" 2>&1)
        if (( $? != 0 )); then
            _wt_line warn "Graphite tracking failed: $gt_output"
        fi
    fi

    if ! $flag_no_init; then
        _wt_worktree_init "$wt_path" "$main_wt"
        # Write branch metadata for the init status display
        local display_branch="${pr_branch:-${explicit_branch:-$name}}"
        echo "$display_branch" > "$_wt_init_status_dir/meta_branch_name"
        if [[ -n "$pr_number" ]]; then
            echo "PR #${pr_number}" > "$_wt_init_status_dir/meta_branch_from"
            touch "$_wt_init_status_dir/meta_branch_pr"
        elif [[ -n "$explicit_branch" ]]; then
            echo "origin/${explicit_branch}" > "$_wt_init_status_dir/meta_branch_from"
            touch "$_wt_init_status_dir/meta_branch_remote"
        elif [[ -n "$base_ref" ]]; then
            echo "$base_ref" > "$_wt_init_status_dir/meta_branch_from"
        fi
    else
        # No init section — print branch line directly
        local display_branch="${pr_branch:-${explicit_branch:-$name}}"
        if [[ -n "$pr_number" ]]; then
            _wt_line ok "Checked out branch ${_WT_C_YELLOW}$display_branch${_WT_C_RESET} from ${_WT_C_YELLOW}PR #${pr_number}${_WT_C_RESET}"
        elif [[ -n "$explicit_branch" ]]; then
            _wt_line ok "Checked out branch ${_WT_C_YELLOW}$display_branch${_WT_C_RESET} from ${_WT_C_YELLOW}origin/${explicit_branch}${_WT_C_RESET}"
        elif [[ -n "$base_ref" ]]; then
            _wt_line ok "Created branch ${_WT_C_YELLOW}$display_branch${_WT_C_RESET} from ${_WT_C_CYAN}$base_ref${_WT_C_RESET}"
        else
            _wt_line ok "Created branch ${_WT_C_YELLOW}$display_branch${_WT_C_RESET}"
        fi
    fi

    # Pop stash into new worktree if we stashed earlier
    if $did_stash; then
        local _pop_output _stash_result
        _pop_output=$(git -C "$wt_path" stash pop 2>&1)
        if (( $? != 0 )); then
            _stash_result="conflicts"
        else
            _stash_result="ok"
        fi
        if ! $flag_no_init && [[ -n "$_wt_init_status_dir" ]]; then
            echo "$_stash_result" > "$_wt_init_status_dir/meta_did_stash"
        else
            if [[ "$_stash_result" == "conflicts" ]]; then
                _wt_line warn "Stash applied with conflicts — resolve manually in the new worktree"
            else
                _wt_line ok "Changes moved to new worktree"
            fi
        fi
    fi

    # Post-create action
    local editor="${editor_override:-$(_wt_config_get editor)}"
    editor="${editor:-code}"

    if $flag_cd; then
        if [[ -n "$_wt_init_status_dir" ]]; then
            _wt_init_prompt "$wt_path" "$editor_override" 2 "used --cd flag"
        else
            _wt_cd "$wt_path"
        fi
        _wt_run_execute "$execute_cmd"
        return 0
    fi

    if $flag_open; then
        if [[ -n "$_wt_init_status_dir" ]]; then
            _wt_init_prompt "$wt_path" "$editor_override" 1 "used --open flag"
        else
            _wt_open "$wt_path" "$editor_override"
        fi
        _wt_skip_execute "$execute_cmd"
        return 0
    fi

    if ! $flag_no_prompt; then
        local on_create
        on_create=$(_wt_config_get on_create 2>/dev/null) || on_create=""

        if [[ "$on_create" == "open" ]]; then
            if [[ -n "$_wt_init_status_dir" ]]; then
                _wt_init_prompt "$wt_path" "$editor_override" 1 "configured by wt init"
            else
                _wt_open "$wt_path" "$editor_override"
            fi
            _wt_skip_execute "$execute_cmd"
        elif [[ "$on_create" == "cd" ]]; then
            if [[ -n "$_wt_init_status_dir" ]]; then
                _wt_init_prompt "$wt_path" "$editor_override" 2 "configured by wt init"
            else
                _wt_cd "$wt_path"
            fi
            _wt_run_execute "$execute_cmd"
        elif [[ "$on_create" == "nothing" ]]; then
            if [[ -n "$_wt_init_status_dir" ]]; then
                _wt_init_prompt "$wt_path" "$editor_override" 3 "configured by wt init"
            else
                _wt_await_init
            fi
            _wt_skip_execute "$execute_cmd"
        elif [[ -n "$_wt_init_status_dir" ]]; then
            _wt_init_prompt "$wt_path" "$editor_override"
            # Check if we cd'd into the worktree (init_prompt handles the action internally)
            if [[ "$PWD" == "$wt_path"* ]]; then
                _wt_run_execute "$execute_cmd"
            else
                _wt_skip_execute "$execute_cmd"
            fi
        else
            # No init tasks — simple picker
            echo ""
            _wt_heading "What next?"
            _wt_pick \
                "o" "Open in $(_wt_editor_name "$editor")" \
                "c" "cd into worktree" \
                "n" "Do nothing"
            local choice=$?
            case $choice in
                0) _wt_open "$wt_path" "$editor_override"; _wt_skip_execute "$execute_cmd" ;;
                1) _wt_cd "$wt_path"; _wt_run_execute "$execute_cmd" ;;
                2|255) _wt_skip_execute "$execute_cmd" ;;
            esac
        fi
    else
        _wt_await_init
        _wt_skip_execute "$execute_cmd"
    fi

    } always {
        _wt_config_transient=false
        _wt_config_overrides=()
    }
}

# List secondary worktree names (one per line)
_wt_secondary_worktrees() {
    local main_wt="$1"
    local wp
    git -C "$main_wt" worktree list --porcelain | while IFS= read -r line; do
        case "$line" in
            worktree\ *)
                wp="${line#worktree }"
                [[ "$wp" != "$main_wt" ]] && basename "$wp"
                ;;
        esac
    done
}

# Resolve a worktree name → path via globals (no stdout, so pickers render correctly).
# Sets REPLY to the worktree path and REPLY2 to the name (basename).
# If name given → validate it exists. If no name and in secondary WT → use current.
# If no name and in main WT → show picker.
_wt_resolve_worktree() {
    local name="${1:-}"
    local main_wt
    main_wt=$(_wt_main_worktree) || return 1
    local parent
    parent=$(_wt_worktree_parent) || parent=$(dirname "$main_wt")

    if [[ -n "$name" ]]; then
        # Name given directly — validate it exists
        if [[ ! -d "$parent/$name" ]]; then
            echo "${_WT_C_RED}Worktree not found: $name${_WT_C_RESET}" >&2
            return 1
        fi
        REPLY="$parent/$name"
        REPLY2="$name"
        return 0
    fi

    local cwd_toplevel
    cwd_toplevel=$(_wt_repo_root 2>/dev/null) || cwd_toplevel=""

    if [[ -n "$cwd_toplevel" && "$cwd_toplevel" != "$main_wt" ]]; then
        # In a secondary worktree — use current
        name=$(basename "$cwd_toplevel")
        REPLY="$parent/$name"
        REPLY2="$name"
        return 0
    fi

    # In main worktree — show picker
    local -a secondaries
    while IFS= read -r wt; do
        [[ -n "$wt" ]] && secondaries+=("$wt")
    done < <(_wt_secondary_worktrees "$main_wt")

    if (( ${#secondaries} == 0 )); then
        echo "  ${_WT_C_YELLOW}No secondary worktrees found.${_WT_C_RESET}" >&2
        return 1
    fi

    echo ""
    _wt_heading "Select worktree:"
    echo ""
    local -a pick_args
    for wt in "${secondaries[@]}"; do
        pick_args+=("$wt" "$wt")
    done
    _wt_pick "${pick_args[@]}"
    local idx=$?
    if (( idx == 255 )); then
        echo "  ${_WT_C_DIM}Cancelled.${_WT_C_RESET}"
        return 1
    fi
    name="${secondaries[$(( idx + 1 ))]}"
    REPLY="$parent/$name"
    REPLY2="$name"
    return 0
}

# Print one status line for a deletion result.
# Args: <name> <status>  (status: ok | not_found | dirty)
_wt_delete_print_line() {
    local name="$1" result="$2"
    case "$result" in
        ok_branch)
            _wt_linef ok "${_WT_C_CYAN}${name}${_WT_C_RESET} deleted ${_WT_C_DIM}(worktree + branch)${_WT_C_RESET}"
            ;;
        ok)
            _wt_linef ok "${_WT_C_CYAN}${name}${_WT_C_RESET} deleted"
            ;;
        not_found)
            _wt_linef err "${_WT_C_CYAN}${name}${_WT_C_RESET} ${_WT_C_DIM}— not found${_WT_C_RESET}"
            ;;
        dirty)
            _wt_linef err "${_WT_C_CYAN}${name}${_WT_C_RESET} ${_WT_C_DIM}— uncommitted changes${_WT_C_RESET}"
            ;;
    esac
}

# Fork a single background worker that processes deletions sequentially.
# Writes per-item status files as each completes for the spinner to poll.
# Args: <status_dir> <main_wt> <parent> <names...>
_wt_start_deletes() {
    setopt LOCAL_OPTIONS NO_MONITOR
    local status_dir="$1" main_wt="$2" parent="$3"
    shift 3
    local -a names=("$@")

    (
        for name in "${names[@]}"; do
            touch "$status_dir/active_${name}"
            wt_path="$parent/$name"

            if [[ ! -d "$wt_path" ]]; then
                echo "not_found" > "$status_dir/done_${name}"
                continue
            fi

            branch=$(git -C "$wt_path" branch --show-current 2>/dev/null)

            if git -C "$main_wt" worktree remove "$wt_path" &>/dev/null; then
                local skip_branch=0
                if [[ -n "$branch" ]]; then
                    # Don't delete the default branch or configured base branch
                    local default_branch=$(_wt_default_branch "$main_wt")
                    local branch_start=$(_wt_config_get branch_start 2>/dev/null || echo "")
                    if [[ "$branch" == "$default_branch" || "$branch" == "$branch_start" ]]; then
                        skip_branch=1
                    fi
                    # Don't delete branches checked out in other worktrees
                    if (( ! skip_branch )) && git -C "$main_wt" worktree list --porcelain 2>/dev/null | grep -q "^branch refs/heads/${branch}$"; then
                        skip_branch=1
                    fi
                fi
                if (( ! skip_branch )) && [[ -n "$branch" ]] && git -C "$main_wt" branch -D "$branch" &>/dev/null; then
                    echo "ok_branch" > "$status_dir/done_${name}"
                else
                    echo "ok" > "$status_dir/done_${name}"
                fi
            else
                echo "dirty" > "$status_dir/done_${name}"
            fi
        done
    ) &!
    echo $! > "$status_dir/pid"
}

# Print final delete results (used when all tasks completed before spinner started).
# Args: <status_dir> <names...>
_wt_delete_results() {
    local status_dir="$1"
    shift
    local name result
    for name in "$@"; do
        result=$(<"$status_dir/done_${name}")
        _wt_delete_print_line "$name" "$result"
    done
}

# Wait for deletions with multi-line spinner. User can press Enter to background.
# Args: <status_dir> <names...>
_wt_await_deletes() {
    setopt LOCAL_OPTIONS NO_MONITOR
    local status_dir="$1"
    shift
    local -a names=("$@")
    local num_names=${#names}

    # Check if all already done
    local -A done_map active_map
    local all_done=true name
    for name in "${names[@]}"; do
        if [[ -f "$status_dir/done_${name}" ]]; then
            done_map[$name]=$(<"$status_dir/done_${name}")
        else
            all_done=false
        fi
        [[ -f "$status_dir/active_${name}" ]] && active_map[$name]=1
    done

    if $all_done; then
        _wt_delete_results "$status_dir" "${names[@]}"
        rm -rf "$status_dir"
        return 0
    fi

    # Layout: num_names lines + 2 tail lines (blank + hint)
    local tail_lines=2
    local total_lines=$(( num_names + tail_lines ))
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local fi_=1 key ii pid

    printf '\033[?25l'
    trap 'printf "\033[?25h"' INT TERM
    for (( ii = 1; ii <= total_lines; ii++ )); do printf "\033[K\n"; done

    while true; do
        if read -rsk 1 -t 0.08 key 2>/dev/null; then
            case "$key" in
                $'\033')
                    # Drain any remaining escape sequence bytes (e.g. arrow keys send \033[A)
                    while read -rsk 1 -t 0.05 _ 2>/dev/null; do :; done
                    ;&
                $'\n'|$'\r'|'')
                    # Background: render final/background states
                    printf "\033[${total_lines}A"
                    for name in "${names[@]}"; do
                        if [[ -n "${done_map[$name]:-}" ]]; then
                            _wt_delete_print_line "$name" "${done_map[$name]}"
                        else
                            printf "  ${_WT_C_DIM}– %s deleting in background${_WT_C_RESET}\033[K\n" "$name"
                        fi
                    done
                    pid=$(<"$status_dir/pid")
                    disown "$pid" 2>/dev/null
                    printf "\033[J"
                    printf '\033[?25h'
                    return 2  # backgrounded
                    ;;
            esac
        fi

        fi_=$(( fi_ % ${#frames} + 1 ))

        # Poll for newly completed/active items
        all_done=true
        for name in "${names[@]}"; do
            if [[ -z "${done_map[$name]:-}" ]] && [[ -f "$status_dir/done_${name}" ]]; then
                done_map[$name]=$(<"$status_dir/done_${name}")
            fi
            if [[ -z "${active_map[$name]:-}" ]] && [[ -f "$status_dir/active_${name}" ]]; then
                active_map[$name]=1
            fi
            [[ -z "${done_map[$name]:-}" ]] && all_done=false
        done

        # Render frame
        printf "\033[${total_lines}A"
        for name in "${names[@]}"; do
            if [[ -n "${done_map[$name]:-}" ]]; then
                _wt_delete_print_line "$name" "${done_map[$name]}"
            elif [[ -n "${active_map[$name]:-}" ]]; then
                printf "  %s ${_WT_C_DIM}Deleting${_WT_C_RESET} ${_WT_C_CYAN}%s${_WT_C_RESET}${_WT_C_DIM}…${_WT_C_RESET}\033[K\n" "${frames[$fi_]}" "$name"
            else
                printf "  ${_WT_C_DIM}  Waiting  %s${_WT_C_RESET}\033[K\n" "$name"
            fi
        done
        # Tail
        printf "\r\033[K\n"
        printf "  ${_WT_C_DIM}press enter to move to background${_WT_C_RESET}\033[K\n"

        $all_done && break
    done

    # All completed naturally — clear tail
    printf "\033[${tail_lines}A"
    printf "\033[J"
    printf '\033[?25h'
    rm -rf "$status_dir"
}

_wt_cmd_delete() {
    local name="$1"
    local main_wt
    main_wt=$(_wt_main_worktree) || return 1
    local parent
    parent=$(_wt_worktree_parent) || parent=$(dirname "$main_wt")

    if [[ -z "$name" ]]; then
        local cwd_toplevel
        cwd_toplevel=$(_wt_repo_root) || return 1

        if [[ "$cwd_toplevel" == "$main_wt" ]]; then
            # In main worktree — multi-select picker
            local -a wt_names
            wt_names=(${(f)"$(_wt_secondary_worktrees "$main_wt")"})

            if (( ${#wt_names} == 0 )); then
                echo ""
                echo "  ${_WT_C_DIM}No secondary worktrees to delete.${_WT_C_RESET}"
                return 0
            fi

            echo ""
            echo "  ${_WT_C_DIM}In main worktree — showing all secondary worktrees.${_WT_C_RESET}"
            echo ""
            _wt_heading "Select worktrees to delete:"
            echo ""
            _wt_multi_pick "${wt_names[@]}"

            if (( ${#_wt_multi_pick_result} == 0 )); then
                echo ""
                echo "  ${_WT_C_DIM}Nothing selected.${_WT_C_RESET}"
                return 0
            fi

            # Check if CWD is inside any selected worktree
            local need_cd=false _orig_dir="$PWD" wt_name
            for wt_name in "${_wt_multi_pick_result[@]}"; do
                case "$PWD" in
                    "$parent/$wt_name"|"$parent/$wt_name"/*) need_cd=true; cd "$main_wt"; break ;;
                esac
            done

            echo ""
            _wt_heading "Deleting ${#_wt_multi_pick_result} worktree(s)…"
            echo ""

            local status_dir
            status_dir=$(mktemp -d) || { echo "${_WT_C_RED}Error: mktemp failed${_WT_C_RESET}" >&2; return 1; }
            _wt_start_deletes "$status_dir" "$main_wt" "$parent" "${_wt_multi_pick_result[@]}"
            _wt_await_deletes "$status_dir" "${_wt_multi_pick_result[@]}"
            local del_rc=$?

            if $need_cd; then
                if (( del_rc == 2 )) || ! [[ -d "$_orig_dir" ]]; then
                    echo ""
                    _wt_line ok "Moved to main worktree"
                else
                    cd "$_orig_dir"
                fi
            fi
            return 0
        fi

        # In a secondary worktree — delete current
        name=$(basename "$cwd_toplevel")

        echo ""
        _wt_heading "Delete current worktree ${_WT_C_YELLOW}${name}${_WT_C_RESET}${_WT_C_BOLD}?"
        echo ""
        _wt_pick y "Yes" n "No"
        (( $? != 0 )) && return 0
    fi

    # Single worktree deletion
    local need_cd=false _orig_dir="$PWD"
    case "$PWD" in
        "$parent/$name"|"$parent/$name"/*) need_cd=true; cd "$main_wt" ;;
    esac

    echo ""
    local status_dir
    status_dir=$(mktemp -d) || { echo "${_WT_C_RED}Error: mktemp failed${_WT_C_RESET}" >&2; return 1; }
    _wt_start_deletes "$status_dir" "$main_wt" "$parent" "$name"
    _wt_await_deletes "$status_dir" "$name"
    local del_rc=$?

    if $need_cd; then
        if (( del_rc == 2 )) || ! [[ -d "$_orig_dir" ]]; then
            echo ""
            _wt_line ok "Moved to main worktree"
        else
            cd "$_orig_dir"
        fi
    fi
}

_wt_worktree_status_summary() {
    local wt_path="$1"
    local dirty ahead behind status_parts=()

    # Dirty count
    dirty=$(git -C "$wt_path" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    (( dirty > 0 )) && status_parts+=("${dirty} dirty")

    # Ahead/behind
    local counts
    counts=$(git -C "$wt_path" rev-list --left-right --count HEAD...@{upstream} 2>/dev/null)
    if [[ -n "$counts" ]]; then
        ahead="${counts%%	*}"
        behind="${counts##*	}"
        (( ahead > 0 )) && status_parts+=("↑${ahead}")
        (( behind > 0 )) && status_parts+=("↓${behind}")
    fi

    if (( ${#status_parts} == 0 )); then
        echo "clean"
    else
        echo "${(j: :)status_parts}"
    fi
}

_wt_cmd_list() {
    local main_wt
    main_wt=$(_wt_main_worktree) || return 1
    local repo_name=$(basename "$main_wt")

    echo ""
    _wt_heading "Worktrees for ${_WT_C_CYAN}$repo_name"
    echo ""

    local wt_path wt_branch name theme current_wt_path
    current_wt_path=$(_wt_repo_root 2>/dev/null) || current_wt_path=""

    # Collect all entries first to calculate column widths
    local -a _list_names _list_branches _list_themes _list_statuses _list_suffixes
    local -i _max_name=0 _max_branch=0 _max_theme=0

    while IFS= read -r line; do
        case "$line" in
            worktree\ *)
                wt_path="${line#worktree }"
                ;;
            branch\ *)
                wt_branch="${line#branch refs/heads/}"
                ;;
            "")
                if [[ "$wt_path" != "$main_wt" && -n "$wt_path" ]]; then
                    name=$(basename "$wt_path")
                    theme=$(_wt_read_worktree_theme "$wt_path")
                    _list_names+=("$name")
                    _list_branches+=("${wt_branch:-(detached)}")
                    _list_themes+=("${theme:-(none)}")
                    _list_statuses+=("$(_wt_worktree_status_summary "$wt_path")")
                    if [[ -n "$current_wt_path" && "$wt_path" == "$current_wt_path" ]]; then
                        _list_suffixes+=("(current)")
                    else
                        _list_suffixes+=("")
                    fi
                    (( ${#name} > _max_name )) && _max_name=${#name}
                    (( ${#_list_branches[-1]} > _max_branch )) && _max_branch=${#_list_branches[-1]}
                    (( ${#_list_themes[-1]} > _max_theme )) && _max_theme=${#_list_themes[-1]}
                fi
                wt_path=""
                wt_branch=""
                ;;
        esac
    done < <(git -C "$main_wt" worktree list --porcelain)

    # Handle last entry (porcelain may not end with blank line)
    if [[ -n "$wt_path" && "$wt_path" != "$main_wt" ]]; then
        name=$(basename "$wt_path")
        theme=$(_wt_read_worktree_theme "$wt_path")
        _list_names+=("$name")
        _list_branches+=("${wt_branch:-(detached)}")
        _list_themes+=("${theme:-(none)}")
        _list_statuses+=("$(_wt_worktree_status_summary "$wt_path")")
        if [[ -n "$current_wt_path" && "$wt_path" == "$current_wt_path" ]]; then
            _list_suffixes+=("(current)")
        else
            _list_suffixes+=("")
        fi
        (( ${#name} > _max_name )) && _max_name=${#name}
        (( ${#_list_branches[-1]} > _max_branch )) && _max_branch=${#_list_branches[-1]}
        (( ${#_list_themes[-1]} > _max_theme )) && _max_theme=${#_list_themes[-1]}
    fi

    if (( ${#_list_names} == 0 )); then
        echo "  ${_WT_C_DIM}(no secondary worktrees)${_WT_C_RESET}"
    else
        local _i
        for (( _i = 1; _i <= ${#_list_names}; _i++ )); do
            local _n="${_list_names[$_i]}"
            local _b="${_list_branches[$_i]}"
            local _t="${_list_themes[$_i]}"
            local _s="${_list_statuses[$_i]}"
            local _sf="${_list_suffixes[$_i]}"

            local _status_display="${_WT_C_DIM}${_s}${_WT_C_RESET}"
            [[ "$_s" == "clean" ]] && _status_display="${_WT_C_GREEN}${_s}${_WT_C_RESET}"
            [[ -n "$_sf" ]] && _sf=" ${_WT_C_DIM}${_sf}${_WT_C_RESET}"

            # Pad using visible string lengths
            local _name_pad=$(( _max_name - ${#_n} ))
            local _branch_pad=$(( _max_branch - ${#_b} ))
            local _theme_pad=$(( _max_theme - ${#_t} ))

            printf "  ${_WT_C_CYAN}%s${_WT_C_RESET}%*s  ${_WT_C_DIM}branch:${_WT_C_RESET} %s%*s  ${_WT_C_DIM}theme:${_WT_C_RESET} ${_WT_C_YELLOW}%s${_WT_C_RESET}%*s  ${_WT_C_DIM}status:${_WT_C_RESET} %s%s\n" \
                "$_n" "$_name_pad" "" \
                "$_b" "$_branch_pad" "" \
                "$_t" "$_theme_pad" "" \
                "$_status_display" "$_sf"
        done
    fi
}

# ---------------------------------------------------------------------------
# wt sync — re-sync gitignored files from main to an existing worktree
# ---------------------------------------------------------------------------

_wt_cmd_sync() {
    setopt LOCAL_OPTIONS NO_MONITOR
    local name=""

    while (( $# > 0 )); do
        case "$1" in
            -*)
                echo "${_WT_C_RED}Unknown flag: $1${_WT_C_RESET}" >&2
                return 1
                ;;
            *)
                if [[ -z "$name" ]]; then
                    name="$1"
                else
                    echo "${_WT_C_RED}Unexpected argument: $1${_WT_C_RESET}" >&2
                    return 1
                fi
                shift
                ;;
        esac
    done

    _wt_resolve_worktree "$name" || return 1
    local wt_path="$REPLY"
    name="$REPLY2"

    local main_wt
    main_wt=$(_wt_main_worktree) || return 1

    if [[ "$wt_path" == "$main_wt" ]]; then
        echo "${_WT_C_RED}Cannot sync main worktree to itself.${_WT_C_RESET}" >&2
        return 1
    fi

    echo ""
    _wt_heading "Syncing gitignored files to ${_WT_C_CYAN}$name"

    _wt_spin "Syncing files…"
    _wt_sync_gitignored "$wt_path" "$main_wt" &>/dev/null
    local sync_rc=$?

    if (( sync_rc == 0 )); then
        local display_cats
        display_cats=$(_wt_config_get sync_categories 2>/dev/null) || display_cats=""
        display_cats="${display_cats//,/, }"
        if [[ -n "$display_cats" ]]; then
            _wt_spin_done "Synced ${display_cats} files to ${name}"
        else
            _wt_spin_done "Gitignored files synced to ${name}"
        fi
    else
        _wt_spin_skip "No sync categories configured — run wt init to configure"
    fi
}

# ---------------------------------------------------------------------------
# wt rename — rename a worktree directory and optionally its branch
# ---------------------------------------------------------------------------

_wt_cmd_rename() {
    local old_name="" new_name=""

    # Parse args: if 2 positional args → old and new; if 1 → resolve old, use arg as new
    local -a positional
    while (( $# > 0 )); do
        case "$1" in
            -*)
                echo "${_WT_C_RED}Unknown flag: $1${_WT_C_RESET}" >&2
                return 1
                ;;
            *)
                positional+=("$1")
                shift
                ;;
        esac
    done

    if (( ${#positional} == 2 )); then
        old_name="${positional[1]}"
        new_name="${positional[2]}"
    elif (( ${#positional} == 1 )); then
        new_name="${positional[1]}"
        # Resolve old name from context
        local main_wt
        main_wt=$(_wt_main_worktree) || return 1
        local cwd_toplevel
        cwd_toplevel=$(_wt_repo_root 2>/dev/null) || cwd_toplevel=""

        if [[ -n "$cwd_toplevel" && "$cwd_toplevel" != "$main_wt" ]]; then
            old_name=$(basename "$cwd_toplevel")
        else
            # In main worktree — show picker
            _wt_resolve_worktree || return 1
            old_name="$REPLY2"
        fi
    elif (( ${#positional} == 0 )); then
        echo "${_WT_C_RED}Usage: wt rename [<old>] <new>${_WT_C_RESET}" >&2
        return 1
    else
        echo "${_WT_C_RED}Too many arguments.${_WT_C_RESET}" >&2
        return 1
    fi

    local main_wt
    main_wt=$(_wt_main_worktree) || return 1
    local parent
    parent=$(_wt_worktree_parent) || parent=$(dirname "$main_wt")

    local old_path="$parent/$old_name"
    local new_path="$parent/$new_name"

    # Validate old exists
    if [[ ! -d "$old_path" ]]; then
        echo "${_WT_C_RED}Worktree not found: $old_name${_WT_C_RESET}" >&2
        return 1
    fi

    # Validate new doesn't exist
    if [[ -d "$new_path" ]]; then
        echo "${_WT_C_RED}Directory already exists: $new_name${_WT_C_RESET}" >&2
        return 1
    fi

    echo ""
    _wt_heading "Renaming worktree ${_WT_C_CYAN}$old_name${_WT_C_RESET}${_WT_C_BOLD} → ${_WT_C_CYAN}$new_name"

    # Move worktree directory
    local move_output
    move_output=$(git -C "$main_wt" worktree move "$old_path" "$new_path" 2>&1)
    if (( $? != 0 )); then
        _wt_line err "Failed to move worktree: ${move_output}"
        return 1
    fi
    _wt_line ok "Directory moved"

    # Rename workspace files: foo.old-name.code-workspace → foo.new-name.code-workspace
    local git_common_dir ws_file
    git_common_dir=$(git -C "$new_path" rev-parse --git-common-dir 2>/dev/null)
    while IFS= read -r ws_file; do
        [[ -z "$ws_file" ]] && continue
        if [[ "${ws_file%.code-workspace}" == *".${old_name}" ]]; then
            local ws_prefix="${ws_file%.${old_name}.code-workspace}"
            local new_ws_file="${ws_prefix}.${new_name}.code-workspace"
            mv "$new_path/$ws_file" "$new_path/$new_ws_file" 2>/dev/null || continue
            # Update shared exclude: remove old entry, add new
            if [[ -n "$git_common_dir" && -f "$git_common_dir/info/exclude" ]]; then
                local tmp="${git_common_dir}/info/exclude.tmp"
                grep -v "^${ws_file}\$" "$git_common_dir/info/exclude" > "$tmp" 2>/dev/null
                mv "$tmp" "$git_common_dir/info/exclude"
                echo "$new_ws_file" >> "$git_common_dir/info/exclude"
            fi
            _wt_line ok "Renamed ${_WT_C_DIM}${ws_file##*/}${_WT_C_RESET} → ${_WT_C_DIM}${new_ws_file##*/}${_WT_C_RESET}"
        fi
    done < <(_wt_find_workspace_files "$new_path")

    # Optionally rename the branch
    local old_branch
    old_branch=$(git -C "$new_path" branch --show-current 2>/dev/null)
    if [[ -n "$old_branch" && "$old_branch" != "$new_name" ]]; then
        echo ""
        _wt_heading "Also rename branch ${_WT_C_YELLOW}$old_branch${_WT_C_RESET}${_WT_C_BOLD} → ${_WT_C_YELLOW}$new_name${_WT_C_RESET}${_WT_C_BOLD}?"
        echo ""
        _wt_pick y "Yes" n "No"
        local rename_idx=$?
        if (( rename_idx == 0 )); then
            local branch_output
            branch_output=$(git -C "$new_path" branch -m "$old_branch" "$new_name" 2>&1)
            if (( $? != 0 )); then
                _wt_line err "Failed to rename branch: ${branch_output}"
            else
                _wt_line ok "Branch renamed to ${_WT_C_YELLOW}$new_name${_WT_C_RESET}"
            fi
        fi
    fi

    # If we're inside the renamed worktree, cd to new path
    case "$PWD" in
        "$old_path"|"$old_path"/*)
            local rel="${PWD#$old_path}"
            cd "${new_path}${rel}"
            _wt_line warn "Moved to new worktree path"
            ;;
    esac
}

# ---------------------------------------------------------------------------
# wt clean — detect and bulk-delete stale worktrees
# ---------------------------------------------------------------------------

_wt_cmd_clean() {
    setopt LOCAL_OPTIONS NO_MONITOR
    local main_wt
    main_wt=$(_wt_main_worktree) || return 1
    local parent
    parent=$(_wt_worktree_parent) || parent=$(dirname "$main_wt")
    local default_branch
    default_branch=$(_wt_default_branch "$main_wt")

    echo ""
    _wt_heading "Checking for stale worktrees…"

    # Fetch and prune to update remote state
    _wt_spin "Fetching remote state…"
    git -C "$main_wt" fetch --prune &>/dev/null
    _wt_spin_done "Remote state updated"

    # Get merged branches
    local -a merged_branches
    merged_branches=(${(f)"$(git -C "$main_wt" branch --merged "$default_branch" 2>/dev/null | sed 's/^[* ]*//')"})

    # Get gone branches (remote tracking branch deleted)
    local -A gone_map
    local _gone_line _gone_br
    while IFS= read -r _gone_line; do
        [[ -z "$_gone_line" ]] && continue
        if [[ "$_gone_line" == *": gone]"* ]]; then
            _gone_br="${_gone_line#[* ] }"
            _gone_br="${_gone_br%% *}"
            gone_map[$_gone_br]=1
        fi
    done < <(git -C "$main_wt" branch -vv 2>/dev/null)

    # Check each secondary worktree
    local -a stale_names stale_labels stale_reasons
    local wt_name wt_branch wt_path reason
    while IFS= read -r wt_name; do
        [[ -z "$wt_name" ]] && continue
        wt_path="$parent/$wt_name"
        wt_branch=$(git -C "$wt_path" branch --show-current 2>/dev/null)
        [[ -z "$wt_branch" ]] && continue

        reason=""
        # Check merged
        local mb
        for mb in "${merged_branches[@]}"; do
            if [[ "$mb" == "$wt_branch" ]]; then
                reason="merged"
                break
            fi
        done

        # Check gone
        if [[ -z "$reason" && -n "${gone_map[$wt_branch]:-}" ]]; then
            reason="gone"
        fi

        if [[ -n "$reason" ]]; then
            stale_names+=("$wt_name")
            stale_reasons+=("$reason")
            local reason_label
            if [[ "$reason" == "merged" ]]; then
                reason_label="${_WT_C_GREEN}merged${_WT_C_RESET}"
            else
                reason_label="${_WT_C_YELLOW}gone${_WT_C_RESET}"
            fi
            stale_labels+=("${wt_name}  ${_WT_C_DIM}branch:${_WT_C_RESET} ${wt_branch}  ${_WT_C_DIM}(${reason_label}${_WT_C_DIM})${_WT_C_RESET}")
        fi
    done < <(_wt_secondary_worktrees "$main_wt")

    if (( ${#stale_names} == 0 )); then
        echo ""
        echo "  ${_WT_C_GREEN}All worktrees are active.${_WT_C_RESET} No stale branches found."
        return 0
    fi

    echo ""
    _wt_heading "Found ${#stale_names} stale worktree(s):"
    echo ""
    _wt_multi_pick --all "${stale_labels[@]}"

    if (( ${#_wt_multi_pick_result} == 0 )); then
        echo ""
        echo "  ${_WT_C_DIM}Nothing selected.${_WT_C_RESET}"
        return 0
    fi

    # Map selected labels back to names
    local -a selected_names
    local i label
    for label in "${_wt_multi_pick_result[@]}"; do
        for (( i = 1; i <= ${#stale_labels}; i++ )); do
            if [[ "$label" == "${stale_labels[$i]}" ]]; then
                selected_names+=("${stale_names[$i]}")
                break
            fi
        done
    done

    # Check if CWD is inside any selected worktree
    local need_cd=false wn
    for wn in "${selected_names[@]}"; do
        case "$PWD" in
            "$parent/$wn"|"$parent/$wn"/*) need_cd=true; cd "$main_wt"; break ;;
        esac
    done

    echo ""
    _wt_heading "Deleting ${#selected_names} worktree(s)…"

    local status_dir
    status_dir=$(mktemp -d) || { echo "${_WT_C_RED}Error: mktemp failed${_WT_C_RESET}" >&2; return 1; }
    _wt_start_deletes "$status_dir" "$main_wt" "$parent" "${selected_names[@]}"
    _wt_await_deletes "$status_dir" "${selected_names[@]}"

    $need_cd && echo "" && _wt_line ok "Moved to main worktree"
}

# ---------------------------------------------------------------------------
# wt open — open or cd into an existing worktree
# ---------------------------------------------------------------------------

_wt_cmd_open() {
    local flag_open=false
    local flag_cd=false
    local editor_override=""
    local execute_cmd=""

    # Expand combined short flags (e.g. -do → -d -o)
    local _expanded_args=()
    for _arg in "$@"; do
        if [[ "$_arg" =~ ^-[a-zA-Z]{2,}$ ]]; then
            local _chars="${_arg#-}"
            local _i
            for (( _i=0; _i < ${#_chars}; _i++ )); do
                _expanded_args+=("-${_chars[$_i+1]}")
            done
        else
            _expanded_args+=("$_arg")
        fi
    done
    set -- "${_expanded_args[@]}"

    # Parse flags (flags can appear before or after the positional name)
    local name=""
    while (( $# > 0 )); do
        case "$1" in
            --open|-o)
                flag_open=true
                shift
                ;;
            --cd|-d)
                flag_cd=true
                shift
                ;;
            --editor|-e)
                editor_override="$2"
                shift 2
                ;;
            --execute|-x)
                execute_cmd="$2"
                shift 2
                ;;
            -*)
                echo "${_WT_C_RED}Unknown flag: $1${_WT_C_RESET}" >&2
                return 1
                ;;
            *)
                name="$1"
                shift
                ;;
        esac
    done
    local main_wt
    main_wt=$(_wt_main_worktree) || return 1
    local parent
    parent=$(_wt_worktree_parent) || parent=$(dirname "$main_wt")

    # --- Step 1: Resolve worktree ---
    if [[ -n "$name" ]]; then
        # Name given directly
        :
    elif [[ "$(_wt_repo_root)" != "$main_wt" ]]; then
        # In a secondary worktree — use current
        name=$(basename "$(_wt_repo_root)")
    else
        # In main worktree — pick from secondaries
        local -a secondaries
        while IFS= read -r wt; do
            [[ -n "$wt" ]] && secondaries+=("$wt")
        done < <(_wt_secondary_worktrees "$main_wt")

        if (( ${#secondaries} == 0 )); then
            echo ""
            echo "  ${_WT_C_YELLOW}No secondary worktrees found.${_WT_C_RESET}"
            echo "  ${_WT_C_DIM}Create one with: wt create${_WT_C_RESET}"
            return 0
        fi

        echo ""
        _wt_heading "Select worktree:"
        echo ""
        local -a pick_args
        for wt in "${secondaries[@]}"; do
            pick_args+=("$wt" "$wt")
        done
        _wt_pick "${pick_args[@]}"
        local idx=$?
        if (( idx == 255 )); then
            echo ""
            echo "  ${_WT_C_DIM}Cancelled.${_WT_C_RESET}"
            return 0
        fi
        name="${secondaries[$(( idx + 1 ))]}"
    fi

    # --- Check for main worktree ---
    local main_name=$(basename "$main_wt")
    if [[ "$name" == "$main_name" ]]; then
        if $flag_cd; then
            cd "$main_wt"
            _wt_run_execute "$execute_cmd"
        elif $flag_open; then
            local editor="${editor_override:-$(_wt_config_get editor 2>/dev/null)}"
            editor="${editor:-code}"
            "$editor" -n "$main_wt"
            _wt_skip_execute "$execute_cmd"
        else
            cd "$main_wt"
            _wt_line ok "Moved to main worktree"
            _wt_run_execute "$execute_cmd"
        fi
        return 0
    fi

    local wt_path="$parent/$name"
    if [[ ! -d "$wt_path" ]]; then
        echo "${_WT_C_RED}Worktree not found: $name${_WT_C_RESET}" >&2
        return 1
    fi

    # --- Step 2: Load workspaces from config, resolve to actual filenames on disk ---
    _wt_resolve_workspaces "$wt_path"
    local -a workspaces=("${reply[@]}")

    # Detect the workspace we're currently inside (to show as non-selectable)
    local current_ws=""
    if (( ${#workspaces} > 0 )) && [[ "$PWD" == "$wt_path"/* ]]; then
        local rel_cwd="${PWD#$wt_path/}"
        local -a filtered_ws
        local ws_dir
        for ws in "${workspaces[@]}"; do
            ws_dir=$(dirname "$ws")
            if [[ "$rel_cwd" == "$ws_dir" || "$rel_cwd" == "$ws_dir/"* ]]; then
                current_ws="$ws"
            else
                filtered_ws+=("$ws")
            fi
        done
        workspaces=("${filtered_ws[@]}")
    fi

    # --- Step 3: Select action ---
    local editor="${editor_override:-$(_wt_config_get editor 2>/dev/null)}"
    editor="${editor:-code}"
    local ed_name
    ed_name=$(_wt_editor_name "$editor")

    local -a _open_action_labels=("Open in $ed_name" "cd into worktree")
    local action_idx
    local _action_preselected=false
    local _action_reason=""
    if $flag_cd; then
        action_idx=1
        _action_preselected=true
        _action_reason="used --cd flag"
    elif $flag_open; then
        action_idx=0
        _action_preselected=true
        _action_reason="used --open flag"
    else
        # Check on_create config for default action
        local _open_on_create
        _open_on_create=$(_wt_config_get on_create 2>/dev/null) || _open_on_create=""
        if [[ "$_open_on_create" == "open" ]]; then
            action_idx=0
            _action_preselected=true
            _action_reason="configured by wt init"
        elif [[ "$_open_on_create" == "cd" ]]; then
            action_idx=1
            _action_preselected=true
            _action_reason="configured by wt init"
        else
            echo ""
            _wt_heading "Open action:"
            _wt_pick o "Open in $ed_name" c "cd into worktree"
            action_idx=$?
            if (( action_idx == 255 )); then
                echo ""
                echo "  ${_WT_C_DIM}Cancelled.${_WT_C_RESET}"
                return 0
            fi
            # Collapse action picker to compact line immediately
            printf "\033[3A"  # up past heading + 2 options
            printf "\r${_WT_C_BOLD}Open action:${_WT_C_RESET} ${_WT_C_CYAN}${_WT_C_BOLD}› %s${_WT_C_RESET}\033[K\n" "${_open_action_labels[$(( action_idx + 1 ))]}"
            printf "\033[J"
        fi
    fi

    # Show compact collapsed line for preselected action
    if $_action_preselected; then
        local _reason_suffix=""
        [[ -n "$_action_reason" ]] && _reason_suffix=" ${_WT_C_DIM}(${_action_reason})${_WT_C_RESET}"
        echo ""
        printf "${_WT_C_BOLD}Open action:${_WT_C_RESET} ${_WT_C_CYAN}${_WT_C_BOLD}› %s${_WT_C_RESET}%b\n" "${_open_action_labels[$(( action_idx + 1 ))]}" "$_reason_suffix"
    fi

    # --- Step 4: Build picker args ---
    local _ws_root_ws=""
    local -a _ws_nested_ws _ws_pick_args
    _wt_build_ws_pick_args "$wt_path" "${workspaces[@]}"

    # --- Step 5: Check default_workspace config ---
    if (( ${#workspaces} > 1 )) && _wt_resolve_default_workspace "$wt_path" "${workspaces[@]}"; then
        local _resolved_ws="$REPLY"
        # Show compact collapsed workspace line
        local _ws_label="${_resolved_ws%.code-workspace}"
        [[ "$_ws_label" == "." ]] && _ws_label="Worktree root ($(basename "$wt_path"))"
        local _ws_heading
        if (( action_idx == 0 )); then
            _ws_heading="Open workspace:"
        else
            _ws_heading="cd to:"
        fi
        printf "${_WT_C_BOLD}${_ws_heading}${_WT_C_RESET} ${_WT_C_CYAN}${_WT_C_BOLD}› %s${_WT_C_RESET} ${_WT_C_DIM}(configured by wt init)${_WT_C_RESET}\n" "$_ws_label"
        if (( action_idx == 1 )); then
            if [[ "$_resolved_ws" == "." || "$(dirname "$_resolved_ws")" == "." ]]; then
                cd "$wt_path"
            else
                cd "$wt_path/$(dirname "$_resolved_ws")"
            fi
            _wt_run_execute "$execute_cmd"
        else
            if [[ "$_resolved_ws" == "." ]]; then
                "$editor" -n "$wt_path"
            else
                "$editor" -n "$wt_path/$_resolved_ws"
            fi
            _wt_skip_execute "$execute_cmd"
        fi
        return 0
    fi

    # --- Step 6: Execute ---
    local _ws_heading _ws_selected_idx _ws_selected_label
    local _num_ws_opts=$(( ${#_ws_pick_args} / 2 ))
    local _has_current_ws=false
    [[ -n "$current_ws" ]] && _has_current_ws=true

    if (( action_idx == 1 )); then
        # cd action
        if (( ${#_ws_pick_args} > 2 )); then
            _wt_heading "cd to:"
            $_has_current_ws && printf "    ${_WT_C_DIM}✗ %s (current)${_WT_C_RESET}\n" "${current_ws%.code-workspace}"
            _wt_pick "${_ws_pick_args[@]}"
            local cd_idx=$?
            if (( cd_idx == 255 )); then
                echo ""
                echo "  ${_WT_C_DIM}Cancelled.${_WT_C_RESET}"
                return 0
            fi
            # Collapse the workspace picker to a compact line
            local _erase_lines=$(( _num_ws_opts + 1 ))
            $_has_current_ws && (( _erase_lines++ ))
            printf "\033[${_erase_lines}A"
            printf "\r${_WT_C_BOLD}cd to:${_WT_C_RESET} ${_WT_C_CYAN}${_WT_C_BOLD}› %s${_WT_C_RESET}\033[K\n" "${_ws_pick_args[$(( (cd_idx) * 2 + 2 ))]}"
            printf "\033[J"
            if (( cd_idx == 0 )); then
                cd "$wt_path"
            else
                local ws_rel="${_ws_nested_ws[$(( cd_idx ))]}"
                cd "$wt_path/$(dirname "$ws_rel")"
            fi
        else
            cd "$wt_path"
        fi
    else
        # Open in editor
        if (( ${#_ws_pick_args} > 2 )); then
            _wt_heading "Open workspace:"
            $_has_current_ws && printf "    ${_WT_C_DIM}✗ %s (current)${_WT_C_RESET}\n" "${current_ws%.code-workspace}"
            _wt_pick "${_ws_pick_args[@]}"
            local ws_idx=$?
            if (( ws_idx == 255 )); then
                echo ""
                echo "  ${_WT_C_DIM}Cancelled.${_WT_C_RESET}"
                return 0
            fi
            # Collapse the workspace picker to a compact line
            local _erase_lines=$(( _num_ws_opts + 1 ))
            $_has_current_ws && (( _erase_lines++ ))
            printf "\033[${_erase_lines}A"
            printf "\r${_WT_C_BOLD}Open workspace:${_WT_C_RESET} ${_WT_C_CYAN}${_WT_C_BOLD}› %s${_WT_C_RESET}\033[K\n" "${_ws_pick_args[$(( (ws_idx) * 2 + 2 ))]}"
            printf "\033[J"
            if (( ws_idx == 0 )); then
                if [[ -n "$_ws_root_ws" ]]; then
                    "$editor" -n "$wt_path/$_ws_root_ws"
                else
                    "$editor" -n "$wt_path"
                fi
            else
                local ws_rel="${_ws_nested_ws[$(( ws_idx ))]}"
                "$editor" -n "$wt_path/$ws_rel"
            fi
        elif [[ -n "$_ws_root_ws" ]]; then
            "$editor" -n "$wt_path/$_ws_root_ws"
        else
            "$editor" -n "$wt_path"
        fi
    fi

    # Run or skip the execute command based on the action taken
    if (( action_idx == 1 )); then
        _wt_run_execute "$execute_cmd"
    else
        _wt_skip_execute "$execute_cmd"
    fi
}

_wt_usage() {
    _wt_banner
    echo ""
    cat <<EOF
${_WT_C_BOLD}Usage:${_WT_C_RESET}
  ${_WT_C_CYAN}wt${_WT_C_RESET}                                          check usage
  ${_WT_C_CYAN}wt init${_WT_C_RESET}                                     configure worktree creation for current repo          ${_WT_C_DIM}# wt i${_WT_C_RESET}
  ${_WT_C_CYAN}wt create${_WT_C_RESET} [<name>] [flags]                  create a worktree and optionally open it              ${_WT_C_DIM}# wt c${_WT_C_RESET}
  ${_WT_C_CYAN}wt open${_WT_C_RESET} [<name>] [flags]                    open or cd into a worktree                            ${_WT_C_DIM}# wt o${_WT_C_RESET}
  ${_WT_C_CYAN}wt delete${_WT_C_RESET} [<name>]                          delete worktree + branch                              ${_WT_C_DIM}# wt d${_WT_C_RESET}
  ${_WT_C_CYAN}wt list${_WT_C_RESET}                                     list worktrees with status                            ${_WT_C_DIM}# wt ls${_WT_C_RESET}
  ${_WT_C_CYAN}wt sync${_WT_C_RESET} [<name>]                           re-sync gitignored files from main to a worktree      ${_WT_C_DIM}# wt s${_WT_C_RESET}
  ${_WT_C_CYAN}wt rename${_WT_C_RESET} [<old>] <new>                    rename a worktree directory and optionally its branch  ${_WT_C_DIM}# wt rn${_WT_C_RESET}
  ${_WT_C_CYAN}wt clean${_WT_C_RESET}                                    detect and delete stale worktrees (merged/gone branches)  ${_WT_C_DIM}# wt cl${_WT_C_RESET}

${_WT_C_BOLD}Create flags:${_WT_C_RESET}
  ${_WT_C_GREEN}-f${_WT_C_RESET}, ${_WT_C_GREEN}--from${_WT_C_RESET} <ref>      start branch from a specific ref
  ${_WT_C_GREEN}-p${_WT_C_RESET}, ${_WT_C_GREEN}--pr${_WT_C_RESET} <number>    create worktree from a GitHub PR (requires gh CLI)
  ${_WT_C_GREEN}-c${_WT_C_RESET}, ${_WT_C_GREEN}--checkout${_WT_C_RESET} <ref>  check out an existing branch, tag, or commit into the worktree
  ${_WT_C_GREEN}-e${_WT_C_RESET}, ${_WT_C_GREEN}--editor${_WT_C_RESET} <name>   override editor (cursor, code, windsurf)
  ${_WT_C_GREEN}-d${_WT_C_RESET}, ${_WT_C_GREEN}--cd${_WT_C_RESET}              cd into the new worktree (skip prompt)
  ${_WT_C_GREEN}-o${_WT_C_RESET}, ${_WT_C_GREEN}--open${_WT_C_RESET}            open in editor (skip prompt)
  ${_WT_C_GREEN}-C${_WT_C_RESET}, ${_WT_C_GREEN}--configure${_WT_C_RESET}       run setup wizard for this worktree only (one-off)
  ${_WT_C_GREEN}-s${_WT_C_RESET}, ${_WT_C_GREEN}--stash${_WT_C_RESET}           stash current changes and pop into new worktree
  ${_WT_C_GREEN}-x${_WT_C_RESET}, ${_WT_C_GREEN}--execute${_WT_C_RESET} <cmd>    run a command in the worktree after opening
  ${_WT_C_GREEN}-n${_WT_C_RESET}, ${_WT_C_GREEN}--no-prompt${_WT_C_RESET}       skip the post-create prompt entirely
  ${_WT_C_GREEN}-N${_WT_C_RESET}, ${_WT_C_GREEN}--no-init${_WT_C_RESET}         skip dependency install & theme setup

${_WT_C_BOLD}Open flags:${_WT_C_RESET}
  ${_WT_C_GREEN}-o${_WT_C_RESET}, ${_WT_C_GREEN}--open${_WT_C_RESET}            open in editor (skip prompt)
  ${_WT_C_GREEN}-d${_WT_C_RESET}, ${_WT_C_GREEN}--cd${_WT_C_RESET}              cd into worktree (skip prompt)
  ${_WT_C_GREEN}-e${_WT_C_RESET}, ${_WT_C_GREEN}--editor${_WT_C_RESET} <name>   override editor (cursor, code, windsurf)
  ${_WT_C_GREEN}-x${_WT_C_RESET}, ${_WT_C_GREEN}--execute${_WT_C_RESET} <cmd>    run a command in the worktree after opening

EOF
}

# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

_wt_require_python() {
    command -v python3 &>/dev/null || {
        echo "${_WT_C_RED}Error: python3 is required but not found in PATH.${_WT_C_RESET}" >&2
        return 1
    }
}

wt() {
    _wt_main "$@"
    local _rc=$?
    echo ""
    return $_rc
}

_wt_main() {
    # Invalidate per-invocation caches
    _wt_main_wt_cache=""
    _wt_repo_root_cache=""
    _wt_conf_map=()
    _wt_patterns_built=false

    # python3 is required for banner, theme, workspace, and PR JSON parsing
    _wt_require_python || return 1

    local subcmd="${1:-}"

    case "$subcmd" in
        init|i)
            _wt_banner
            _wt_cmd_init
            ;;
        create|c)
            _wt_banner
            shift
            _wt_cmd_create "$@"
            ;;
        open|o)
            _wt_ensure_setup || return 1
            shift
            _wt_cmd_open "$@"
            ;;
        delete|d)
            _wt_ensure_setup || return 1
            shift
            _wt_cmd_delete "$@"
            ;;
        list|ls|l)
            _wt_ensure_setup || return 1
            _wt_cmd_list
            ;;
        sync|s)
            _wt_ensure_setup || return 1
            shift
            _wt_cmd_sync "$@"
            ;;
        rename|rn)
            _wt_ensure_setup || return 1
            shift
            _wt_cmd_rename "$@"
            ;;
        clean|cl)
            _wt_ensure_setup || return 1
            _wt_cmd_clean
            ;;
        --help|-h)
            _wt_usage
            ;;
        "")
            local conf
            conf=$(_wt_config_file 2>/dev/null)
            if [[ -z "$conf" || ! -f "$conf" ]]; then
                _wt_banner
                _wt_cmd_init
            else
                _wt_usage
            fi
            ;;
        *)
            echo "${_WT_C_RED}Unknown subcommand: $subcmd${_WT_C_RESET}" >&2
            echo "${_WT_C_DIM}Run 'wt --help' for usage.${_WT_C_RESET}" >&2
            return 1
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Completion
# ---------------------------------------------------------------------------

_wt_completion() {
    local curcontext="$curcontext" state line
    typeset -A opt_args

    _arguments -C \
        '1: :->subcmd' \
        '*:: :->args' \
        && return 0

    case $state in
        subcmd)
            local -a subcmds=(
                'init:Configure editor and dependency directories'
                'i:Shorthand for init'
                'create:Create a new worktree'
                'c:Shorthand for create'
                'open:Open or cd into a worktree'
                'o:Shorthand for open'
                'delete:Delete a worktree and its branch'
                'd:Shorthand for delete'
                'list:List worktrees with status'
                'ls:Shorthand for list'
                'l:Shorthand for list'
                'sync:Re-sync gitignored files from main to a worktree'
                's:Shorthand for sync'
                'rename:Rename a worktree directory and optionally its branch'
                'rn:Shorthand for rename'
                'clean:Detect and delete stale worktrees'
                'cl:Shorthand for clean'
            )
            _describe -t commands 'subcommand' subcmds
            ;;
        args)
            case "${line[1]}" in
                create|c)
                    _arguments \
                        '(-f --from)'{-f,--from}'[Start branch from a specific ref]:ref:' \
                        '(-p --pr)'{-p,--pr}'[Create worktree from a GitHub PR]:number:' \
                        '(-c --checkout)'{-c,--checkout}'[Check out an existing branch, tag, or commit]:ref:' \
                        '(-e --editor)'{-e,--editor}'[Override editor]:editor:(cursor code windsurf)' \
                        '(-d --cd)'{-d,--cd}'[cd into the new worktree]' \
                        '(-o --open)'{-o,--open}'[Open in editor]' \
                        '(-C --configure)'{-C,--configure}'[Run setup wizard for this worktree only]' \
                        '(-s --stash)'{-s,--stash}'[Stash current changes and pop into new worktree]' \
                        '(-n --no-prompt)'{-n,--no-prompt}'[Skip post-create prompt]' \
                        '(-N --no-init)'{-N,--no-init}'[Skip init]' \
                        '1::name:'
                    ;;
                sync|s)
                    _arguments \
                        '1::name:_wt_complete_worktrees'
                    ;;
                rename|rn)
                    _arguments \
                        '1::old name:_wt_complete_worktrees' \
                        '2::new name:'
                    ;;
                open|o)
                    _arguments \
                        '(-o --open)'{-o,--open}'[Open in editor]' \
                        '(-d --cd)'{-d,--cd}'[cd into worktree]' \
                        '(-e --editor)'{-e,--editor}'[Override editor]:editor:(cursor code windsurf)' \
                        '1::name:_wt_complete_worktrees'
                    ;;
                delete|d)
                    _wt_complete_worktrees
                    ;;
            esac
            ;;
    esac
}

_wt_complete_worktrees() {
    local main_wt
    main_wt=$(git worktree list --porcelain 2>/dev/null | head -1 | sed 's/^worktree //')
    if [[ -n "$main_wt" ]]; then
        local -a wts
        local wp pline
        while IFS= read -r pline; do
            case "$pline" in
                worktree\ *)
                    wp="${pline#worktree }"
                    [[ "$wp" != "$main_wt" ]] && wts+=("$(basename "$wp")")
                    ;;
            esac
        done < <(git worktree list --porcelain 2>/dev/null)
        _describe -t worktrees 'worktree' wts
    fi
}

(( $+functions[compdef] )) && compdef _wt_completion wt
