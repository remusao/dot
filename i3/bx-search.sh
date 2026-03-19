#!/bin/bash
# bx-search.sh — Brave Search via rofi script mode
# Usage: rofi -show bx -modes "bx:~/.i3/bx-search.sh"
set -eu

parse_mode() {
    case "$1" in
        web:*)  echo web ;;
        news:*) echo news ;;
        rag:*)  echo context ;;
        *)      echo ai ;;
    esac
}

parse_query() {
    case "$1" in
        web:*)  echo "${1#web:}" ;;
        news:*) echo "${1#news:}" ;;
        rag:*)  echo "${1#rag:}" ;;
        *)      echo "$1" ;;
    esac
}

emit_web() {
    bx web "$1" --count 10 2>/dev/null \
      | jq -r '.web.results[:12][] |
          "<b>\(.title | gsub("<[^>]*>"; "") | gsub("&"; "\u0026amp;"))</b>  \(.description | gsub("<[^>]*>"; "") | gsub("&"; "\u0026amp;") | .[0:120])\u0000info\u001f\(.url)"'
}

emit_news() {
    bx news "$1" --count 10 2>/dev/null \
      | jq -r '.results[:12][] |
          "<b>\(.title | gsub("<[^>]*>"; "") | gsub("&"; "\u0026amp;"))</b>  <i>\(.age // "")</i>  \(.description | gsub("<[^>]*>"; "") | gsub("&"; "\u0026amp;") | .[0:100])\u0000info\u001f\(.url)"'
}

emit_context() {
    bx context "$1" --count 8 2>/dev/null \
      | jq -r '.grounding.generic[:12][] |
          "<b>\(.title | gsub("<[^>]*>"; "") | gsub("&"; "\u0026amp;"))</b>  \(.snippets[0:1] | join(" ") | gsub("<[^>]*>"; "") | gsub("&"; "\u0026amp;") | .[0:120])\u0000info\u001f\(.url)"'
}

handle_ai() {
    (
        local tag="bx-answer" answer=""
        dunstify -a bx-search -u normal -t 0 -h "string:x-dunst-stack-tag:$tag" \
            "Brave AI" "Thinking..."

        while IFS= read -r -N 30 chunk; do
            answer="${answer}${chunk}"
            local safe="${answer//&/&amp;}"
            safe="${safe//</\&lt;}"
            safe="${safe//>/\&gt;}"
            dunstify -a bx-search -u normal -t 0 -h "string:x-dunst-stack-tag:$tag" \
                "Brave AI" "$(printf '%.500s' "$safe")"
        done < <(bx answers "$1" 2>/dev/null | jq -jr --unbuffered '.choices[0].delta.content // empty')
        [ -n "${chunk:-}" ] && answer="${answer}${chunk}"

        if [ -z "$answer" ]; then
            dunstify -a bx-search -u normal -t 5000 "bx" "No answer returned"
            exit 0
        fi
        printf '%s' "$answer" | xclip -selection clipboard
        local safe="${answer//&/&amp;}"
        safe="${safe//</\&lt;}"
        safe="${safe//>/\&gt;}"
        dunstify -a bx-search -u normal -t 8000 -h "string:x-dunst-stack-tag:$tag" \
            "Brave AI (copied)" "$(printf '%.500s' "$safe")"
    ) </dev/null >/dev/null 2>&1 &
}

case "${ROFI_RETV:-0}" in
    0)
        echo -en "\0prompt\x1fbx\n"
        echo -en "\0markup-rows\x1ftrue\n"
        echo -en "\0message\x1fAI answer (default) \xc2\xb7 web: search \xc2\xb7 news: headlines \xc2\xb7 rag: context\n"
        echo -en "Type a query and press Enter\0nonselectable\x1ftrue\n"
        ;;
    2)
        [ -z "${1:-}" ] && exit 0
        mode=$(parse_mode "$1")
        query=$(parse_query "$1")
        query="${query# }"

        echo -en "\0prompt\x1fbx\n"
        echo -en "\0markup-rows\x1ftrue\n"

        case "$mode" in
            ai)
                handle_ai "$query"
                exit 0
                ;;
            *)
                echo -en "\0message\x1f${mode} results for: ${query}\n"
                case "$mode" in
                    web)     emit_web "$query" ;;
                    news)    emit_news "$query" ;;
                    context) emit_context "$query" ;;
                esac
                ;;
        esac
        ;;
    1)
        url="${ROFI_INFO:-}"
        [ -n "$url" ] && coproc ( xdg-open "$url" >/dev/null 2>&1 )
        ;;
esac
