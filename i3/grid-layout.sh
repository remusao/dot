#!/bin/bash
# grid-layout.sh — Toggle between grid layout and previous layout
# Keybinding: $mod+g exec --no-startup-id ~/.i3/grid-layout.sh
set -eu

# Get focused workspace name
ws=$(i3-msg -t get_workspaces | jq -r '.[] | select(.focused) | .name')

# Cache the full tree (one IPC call, multiple jq passes)
tree=$(i3-msg -t get_tree)

# Get the currently focused window's con_id
focused_id=$(jq -r '(first(.. | objects | select(.focused == true)) | .id) // 0' <<< "$tree")

# Get all tiled leaf window IDs on the focused workspace
mapfile -t wins < <(
    jq -r --arg ws "$ws" '
        def tiled_leaves:
            if (.nodes | length) == 0 and .window != null then [.]
            else [.nodes[] | tiled_leaves] | add // []
            end;
        first(.. | objects | select(.type == "workspace" and .name == $ws)) |
        tiled_leaves[] | .id
    ' <<< "$tree"
)

n=${#wins[@]}
(( n <= 1 )) && exit 0

state_file="/tmp/i3-grid-layout-${ws}.json"

# Move all tiled windows to scratchpad and ensure workspace persists
move_to_scratchpad() {
    local cmd=""
    for id in "${wins[@]}"; do
        cmd+="[con_id=$id] move scratchpad; "
    done
    i3-msg -q "${cmd}workspace --no-auto-back-and-forth ${ws}"
}

if [[ -f "$state_file" ]]; then
    # Check if saved windows match current windows
    saved_ids=$(jq -r '[.. | objects | .id // empty] | sort | map(tostring) | join(",")' "$state_file")
    current_ids=$(printf '%s\n' "${wins[@]}" | sort -n | paste -sd,)

    if [[ "$saved_ids" == "$current_ids" ]]; then
        # REVERT: restore saved layout
        move_to_scratchpad

        # Generate and execute restore commands from saved tree
        mapfile -t cmds < <(
            jq -r '
                def first_leaf: if .children then .children[0] | first_leaf else . end;
                def restore:
                    if .children | not then []
                    else
                        (if (.children | length) > 1 then
                            [if .layout == "splith" then "split h" else "split v" end] +
                            [.children[1:][] | "show \(first_leaf.id)"]
                        else [] end) +
                        ([.children[] | select(.children) |
                            ["focus \(first_leaf.id)"] + restore
                        ] | add // [])
                    end;
                "show \(first_leaf.id)", restore[]
            ' "$state_file"
        )

        for cmd in "${cmds[@]}"; do
            case "$cmd" in
                show\ *)  i3-msg -q "[con_id=${cmd#show }] scratchpad show, floating disable" ;;
                split\ *) i3-msg -q "$cmd" ;;
                focus\ *) i3-msg -q "[con_id=${cmd#focus }] focus" ;;
            esac
        done

        rm -f "$state_file"
        (( focused_id )) && i3-msg -q "[con_id=$focused_id] focus"
        exit 0
    fi

    # Windows changed — discard stale state, fall through to grid
    rm -f "$state_file"
fi

# GRID: save current layout, then apply grid

jq -c --arg ws "$ws" '
    def simplify:
        if (.nodes | length) == 0 and .window != null then {id: .id}
        elif (.nodes | length) > 0 then {layout: .layout, children: [.nodes[] | simplify]}
        else empty
        end;
    first(.. | objects | select(.type == "workspace" and .name == $ws)) | simplify
' <<< "$tree" > "$state_file"

# Grid dimensions: cols = ceil(sqrt(n))
cols=1
while (( cols * cols < n )); do (( cols++ )); done
rows=$(( (n + cols - 1) / cols ))
extra=$(( n % cols ))

move_to_scratchpad

# Place first row (column heads in horizontal split)
cmd="[con_id=${wins[0]}] scratchpad show, floating disable"
if (( cols > 1 )); then
    cmd+="; split h"
    for (( c = 1; c < cols; c++ )); do
        cmd+="; [con_id=${wins[$c]}] scratchpad show, floating disable"
    done
fi
i3-msg -q "$cmd"

# Fill each column vertically
for (( c = 0; c < cols; c++ )); do
    if (( extra > 0 && c < extra )); then
        col_count=$rows
    else
        col_count=$(( n / cols ))
    fi
    (( col_count <= 1 )) && continue

    cmd="[con_id=${wins[$c]}] focus; split v"
    for (( r = 1; r < col_count; r++ )); do
        idx=$(( c + r * cols ))
        cmd+="; [con_id=${wins[$idx]}] scratchpad show, floating disable"
    done
    i3-msg -q "$cmd"
done

(( focused_id )) && i3-msg -q "[con_id=$focused_id] focus"
