#!/bin/bash
# ws-overview.sh -- Workspace overview (rofi script mode)
# Usage: rofi -show ws -modes "ws:~/.i3/ws-overview.sh"
set -eu

case "${ROFI_RETV:-0}" in
0)
    echo -en "\0prompt\x1fws\n"
    echo -en "\0markup-rows\x1ftrue\n"
    echo -en "\0no-custom\x1ftrue\n"

    i3-msg -t get_tree | jq -r '
      def leaves:
        if .window != null then [.]
        elif .type == "floating_con" then [.nodes[]? | leaves] | add // []
        else [(.nodes[]?, .floating_nodes[]?) | leaves] | add // []
        end;
      def esc: gsub("&";"&amp;") | gsub("<";"&lt;") | gsub(">";"&gt;");

      [.nodes[] | select(.name != "__i3") | .name as $out |
       .nodes[] | select(.type == "con") | .nodes[] |
       select(.type == "workspace") |
       {ws: .name, out: $out, wins: leaves}
      ] | sort_by(.ws | tonumber? // 999) | .[] |

      (.wins | length) as $n |
      (.wins | any(.focused)) as $foc |

      (if $foc then "<b><span color=\"#285577\">\(.ws)</span></b>"
       else "<b>\(.ws)</b>" end) +
      "  <span color=\"#888888\">\(.out)" +
      (if $n > 0 then "  \($n)" else "" end) +
      "</span>" +
      "\u0000nonselectable\u001f\(if $n > 0 then "true" else "false" end)" +
      (if $n == 0 then "\u001finfo\u001fws:\(.ws)" else "" end) +
      "\u001ficon\u001fuser-desktop",

      (.wins[] |
        "    \(if .focused then "<b>\(.name // "?" | esc)</b>"
              else (.name // "?" | esc) end)" +
        "\u0000icon\u001f\(.window_properties.class // "application" | ascii_downcase)" +
        "\u001finfo\u001fcon:\(.id)"
      )
    '
    ;;
1)
    case "${ROFI_INFO:-}" in
        con:*) i3-msg "[con_id=${ROFI_INFO#con:}] focus" >/dev/null ;;
        ws:*)  i3-msg "workspace --no-auto-back-and-forth ${ROFI_INFO#ws:}" >/dev/null ;;
    esac
    ;;
esac
