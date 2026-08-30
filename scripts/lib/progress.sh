#!/usr/bin/env bash
# A pinned status line across the bottom of the terminal.
#
# The driver streams a stage's output for many minutes; without this there is
# no way to tell "working" from "stalled" except by watching lines scroll. The
# line is pinned with a DEC scrolling region, so stage output keeps scrolling
# normally above it instead of fighting it for the cursor.
#
# Everything writes to /dev/tty, never to stdout: the driver's stdout is piped
# and redirected, and escape sequences in a log would corrupt it. When there is
# no terminal every function here is a no-op, so a redirected run is unchanged.
#
# bash 3.2 compatible: no associative arrays, no ${var^^}.

PROGRESS_ACTIVE=0

progress_supported() {
    [[ -t 1 ]] || return 1
    [[ -n "${TERM:-}" && "$TERM" != "dumb" ]] || return 1
    [[ -w /dev/tty ]] 2>/dev/null || return 1
    command -v tput > /dev/null 2>&1
}

# progress_bar_line <done> <total> <width> <label> — the rendered text.
#
# Pure: no terminal, no escape codes, no side effects, so the arithmetic and
# truncation are testable without a tty.
progress_bar_line() {
    local done="$1" total="$2" width="$3" label="$4"
    local pct=0 filled=0 bar_width text

    if [[ "$total" -gt 0 ]]; then
        pct=$(( done * 100 / total ))
    fi
    [[ "$pct" -gt 100 ]] && pct=100
    [[ "$pct" -lt 0 ]] && pct=0

    # label + " [bar] 100% (nnn/nnn)" — reserve the fixed part, bar takes the rest.
    local suffix
    suffix="$(printf '%3d%% (%d/%d)' "$pct" "$done" "$total")"
    bar_width=$(( width - ${#label} - ${#suffix} - 4 ))
    [[ "$bar_width" -lt 4 ]] && bar_width=0

    if [[ "$bar_width" -gt 0 ]]; then
        filled=$(( bar_width * pct / 100 ))
        local bar=""
        local i=0
        while [[ "$i" -lt "$bar_width" ]]; do
            if [[ "$i" -lt "$filled" ]]; then bar="$bar#"; else bar="$bar."; fi
            i=$(( i + 1 ))
        done
        text="$label [$bar] $suffix"
    else
        text="$label $suffix"
    fi

    # Never exceed the width: a wrapped status line breaks the scrolling region.
    printf '%s' "${text:0:$width}"
}

# progress_begin — reserve the last row and keep stage output above it.
progress_begin() {
    progress_supported || return 0
    local rows
    rows="$(tput lines 2>/dev/null || echo 24)"
    [[ "$rows" -gt 2 ]] || return 0
    PROGRESS_ACTIVE=1
    # Scrolling region = rows 1..rows-1, then park the cursor inside it.
    printf '\033[1;%dr\033[%d;1H' "$(( rows - 1 ))" "$(( rows - 1 ))" > /dev/tty
}

# progress_update <done> <total> <label>
progress_update() {
    [[ "$PROGRESS_ACTIVE" == "1" ]] || return 0
    local rows cols
    rows="$(tput lines 2>/dev/null || echo 24)"
    cols="$(tput cols 2>/dev/null || echo 80)"
    # Save cursor, jump to the reserved row, clear it, bold, draw, restore.
    printf '\0337\033[%d;1H\033[2K\033[1m%s\033[0m\0338' \
        "$rows" "$(progress_bar_line "$1" "$2" "$cols" "$3")" > /dev/tty
}

# progress_end — release the row. Safe to call when never begun.
progress_end() {
    [[ "$PROGRESS_ACTIVE" == "1" ]] || return 0
    PROGRESS_ACTIVE=0
    local rows
    rows="$(tput lines 2>/dev/null || echo 24)"
    # Reset the scrolling region first, or the cleared row stays reserved.
    printf '\033[r\033[%d;1H\033[2K' "$rows" > /dev/tty
}
