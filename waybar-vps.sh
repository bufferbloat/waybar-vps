#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${WAYBAR_VPS_CONFIG:-$SCRIPT_DIR/config}"

DISPLAY_NAME="vps"
DISPLAY_STYLE="count"
TIMEOUT="3"
HTTP_HEADER=""
UP_TEXT="up"
DOWN_TEXT="down"
ERROR_TEXT="error"

# Legacy single-server options remain supported.
NAME=""
CHECK_TYPE="auto"
TARGET=""
ENDPOINT=""
PORT="22"
EXPECT_STATUS="200"

SERVERS=()

json_output() {
    local text="$1"
    local class="$2"
    local tooltip="$3"

    jq -cn \
        --arg text "$text" \
        --arg class "$class" \
        --arg tooltip "$tooltip" \
        '{text: $text, class: $class, alt: $class, tooltip: $tooltip}'
}

pango_escape() {
    local value="$1"

    value="${value//&/\&amp;}"
    value="${value//</\&lt;}"
    value="${value//>/\&gt;}"
    printf '%s' "$value"
}

trim() {
    local value="$1"

    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

load_config() {
    local line key value

    [[ -r "$CONFIG_FILE" ]] || return 1

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="$(trim "$line")"
        [[ -z "$line" || "$line" == \#* || "$line" != *=* ]] && continue

        key="$(trim "${line%%=*}")"
        value="$(trim "${line#*=}")"

        case "$key" in
            SERVER) SERVERS+=("$value") ;;
            DISPLAY_NAME|DISPLAY_STYLE|TIMEOUT|HTTP_HEADER|UP_TEXT|DOWN_TEXT|ERROR_TEXT)
                printf -v "$key" '%s' "$value"
                ;;
            NAME|CHECK_TYPE|TARGET|ENDPOINT|PORT|EXPECT_STATUS)
                printf -v "$key" '%s' "$value"
                ;;
        esac
    done < "$CONFIG_FILE"

    [[ -n "$NAME" ]] && DISPLAY_NAME="$NAME"

    if (( ${#SERVERS[@]} == 0 )) && [[ -n "$TARGET" || -n "$ENDPOINT" ]]; then
        local type="$CHECK_TYPE"
        local target="$TARGET"
        local option=""

        if [[ "$type" == "auto" ]]; then
            [[ -n "$ENDPOINT" ]] && type="http" || type="ping"
        fi

        case "$type" in
            http)
                target="$ENDPOINT"
                option="$EXPECT_STATUS"
                ;;
            tcp) option="$PORT" ;;
        esac

        SERVERS+=("${DISPLAY_NAME}|${type}|${target}|${option}")
    fi
}

write_result() {
    local file="$1"
    local name="$2"
    local state="$3"
    local detail="$4"

    jq -cn \
        --arg name "$name" \
        --arg state "$state" \
        --arg detail "$detail" \
        '{name: $name, state: $state, detail: $detail}' > "$file"
}

check_server() {
    local spec="$1"
    local result_file="$2"
    local name type target option extra
    local output latency result status

    IFS='|' read -r name type target option extra <<< "$spec"
    name="$(trim "${name:-}")"
    type="$(trim "${type:-}")"
    target="$(trim "${target:-}")"
    option="$(trim "${option:-}")"

    [[ -n "$name" ]] || name="server"
    [[ -n "$type" ]] || type="auto"

    if [[ -n "${extra:-}" ]]; then
        write_result "$result_file" "$name" error "too many SERVER fields"
        return
    fi

    if [[ "$type" == "auto" ]]; then
        [[ "$target" == http://* || "$target" == https://* ]] && type="http" || type="ping"
    fi

    case "$type" in
        ping)
            if ! command -v ping >/dev/null 2>&1; then
                write_result "$result_file" "$name" error "ping is required"
            elif [[ -z "$target" ]]; then
                write_result "$result_file" "$name" error "ping target is not configured"
            elif output="$(ping -n -c 1 -W "$TIMEOUT" -- "$target" 2>/dev/null)"; then
                latency="$(awk -F'time=' '/time=/{print $2}' <<< "$output" | awk '{print $1}' | head -n1)"
                write_result "$result_file" "$name" up "${target} reachable${latency:+ in ${latency} ms}"
            else
                write_result "$result_file" "$name" down "${target} did not answer within ${TIMEOUT}s"
            fi
            ;;
        http)
            status="${option:-200}"
            if ! command -v curl >/dev/null 2>&1; then
                write_result "$result_file" "$name" error "curl is required"
            elif [[ -z "$target" ]]; then
                write_result "$result_file" "$name" error "HTTP endpoint is not configured"
            elif [[ ! "$status" =~ ^[1-5][0-9][0-9]$|^000$ ]]; then
                write_result "$result_file" "$name" error "invalid expected HTTP status: ${status}"
            else
                local -a curl_args=(
                    --silent
                    --show-error
                    --output /dev/null
                    --max-time "$TIMEOUT"
                    --write-out '%{http_code} %{time_total}'
                )
                [[ -n "$HTTP_HEADER" ]] && curl_args+=(--header "$HTTP_HEADER")

                if result="$(curl "${curl_args[@]}" --url "$target" 2>/dev/null)"; then
                    read -r output latency <<< "$result"
                    if [[ "$output" == "$status" ]]; then
                        write_result "$result_file" "$name" up "${target} returned HTTP ${output} in ${latency}s"
                    else
                        write_result "$result_file" "$name" down "${target} returned HTTP ${output}; expected ${status}"
                    fi
                else
                    write_result "$result_file" "$name" down "${target} did not respond within ${TIMEOUT}s"
                fi
            fi
            ;;
        tcp)
            option="${option:-22}"
            if ! command -v timeout >/dev/null 2>&1; then
                write_result "$result_file" "$name" error "GNU timeout is required"
            elif [[ -z "$target" ]]; then
                write_result "$result_file" "$name" error "TCP target is not configured"
            elif [[ ! "$option" =~ ^[1-9][0-9]*$ ]] || (( ${#option} > 5 )) || (( 10#$option > 65535 )); then
                write_result "$result_file" "$name" error "invalid TCP port: ${option}"
            elif timeout "$TIMEOUT" bash -c 'exec 3<>"/dev/tcp/$1/$2"' _ "$target" "$option" 2>/dev/null; then
                write_result "$result_file" "$name" up "${target}:${option} accepts TCP connections"
            else
                write_result "$result_file" "$name" down "${target}:${option} did not accept a connection within ${TIMEOUT}s"
            fi
            ;;
        *)
            write_result "$result_file" "$name" error "unknown check type: ${type}"
            ;;
    esac
}

state_color() {
    case "$1" in
        up) printf '#a6e3a1' ;;
        down) printf '#f38ba8' ;;
        *) printf '#f9e2af' ;;
    esac
}

render_results() {
    local result_file name state detail color
    local total="${#SERVERS[@]}"
    local up=0
    local down=0
    local errors=0
    local tooltip=""
    local circles=""
    local class text status_text

    for result_file in "$@"; do
        name="$(jq -r '.name' "$result_file")"
        state="$(jq -r '.state' "$result_file")"
        detail="$(jq -r '.detail' "$result_file")"
        color="$(state_color "$state")"

        case "$state" in
            up) (( up += 1 )) ;;
            down) (( down += 1 )) ;;
            *) (( errors += 1 )) ;;
        esac

        tooltip+="${tooltip:+$'\n'}$(pango_escape "$name"): $(pango_escape "$detail")"
        circles+="${circles:+ }<span foreground=\"${color}\">●</span>"
    done

    if (( down > 0 )); then
        class="down"
    elif (( errors > 0 )); then
        class="error"
    else
        class="up"
    fi

    color="$(state_color "$class")"
    if (( total == 1 )); then
        case "$class" in
            up) status_text="$UP_TEXT" ;;
            down) status_text="$DOWN_TEXT" ;;
            *) status_text="$ERROR_TEXT" ;;
        esac
        text="$(pango_escape "$DISPLAY_NAME"): <span foreground=\"${color}\">$(pango_escape "$status_text")</span>"
    elif [[ "$DISPLAY_STYLE" == "circles" ]]; then
        text="$(pango_escape "$DISPLAY_NAME"): ${circles}"
    else
        text="$(pango_escape "$DISPLAY_NAME"): <span foreground=\"${color}\">${up}/${total}</span>"
    fi

    json_output "$text" "$class" "$tooltip"
}

status() {
    local tmp_dir index result_file
    local -a result_files=()
    local -a pids=()

    command -v jq >/dev/null 2>&1 || {
        printf '{"text":"vps: error","class":"error","alt":"error","tooltip":"jq is required"}\n'
        return
    }

    if ! load_config; then
        json_output "vps: error" error "Config not found: ${CONFIG_FILE}"
        return
    fi

    if [[ ! "$TIMEOUT" =~ ^[1-9][0-9]*$ ]]; then
        json_output "$(pango_escape "$DISPLAY_NAME"): error" error "TIMEOUT must be a positive integer"
        return
    fi

    if [[ "$DISPLAY_STYLE" != "count" && "$DISPLAY_STYLE" != "circles" ]]; then
        json_output "$(pango_escape "$DISPLAY_NAME"): error" error "DISPLAY_STYLE must be count or circles"
        return
    fi

    if (( ${#SERVERS[@]} == 0 )); then
        json_output "$(pango_escape "$DISPLAY_NAME"): error" error "No SERVER entries configured"
        return
    fi

    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' EXIT

    for index in "${!SERVERS[@]}"; do
        result_file="${tmp_dir}/$(printf '%04d' "$index").json"
        result_files+=("$result_file")
        check_server "${SERVERS[$index]}" "$result_file" &
        pids+=("$!")
    done

    for index in "${!pids[@]}"; do
        wait "${pids[$index]}" || write_result "${result_files[$index]}" server error "check failed unexpectedly"
    done

    render_results "${result_files[@]}"
    rm -rf "$tmp_dir"
    trap - EXIT
}

case "${1:---status}" in
    --status) status ;;
    --print-config) printf '%s\n' "$CONFIG_FILE" ;;
    *)
        printf 'Usage: %s [--status|--print-config]\n' "$0" >&2
        exit 2
        ;;
esac
