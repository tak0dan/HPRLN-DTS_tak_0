#!/usr/bin/env bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  #
# Kitty Themes Source https://github.com/dexpota/kitty-themes #

# Define directories and variables
kitty_themes_DiR="$HOME/.config/kitty/kitty-themes" # Kitty Themes Directory
kitty_config="$HOME/.config/kitty/kitty.conf"
iDIR="$HOME/.config/swaync/images" # For notifications
rofi_theme_for_this_script="$HOME/.config/rofi/config-kitty-theme.rasi"

# --- Helper Functions ---
notify_user() {
  notify-send -u low -i "$1" "$2" "$3"
}

# Function to apply the selected kitty theme
apply_kitty_theme_to_config() {
  local theme_name_to_apply="$1"
  if [ -z "$theme_name_to_apply" ]; then
    echo "Error: No theme name provided to apply_kitty_theme_to_config." >&2
    return 1
  fi

  local theme_file_path_to_apply="$kitty_themes_DiR/$theme_name_to_apply.conf"
  if [ ! -f "$theme_file_path_to_apply" ]; then
    notify_user "$iDIR/error.png" "Error" "Theme file not found: $theme_name_to_apply.conf"
    return 1
  fi

  local temp_kitty_config_file
  temp_kitty_config_file=$(mktemp)
  cp "$kitty_config" "$temp_kitty_config_file"

  if grep -q -E '^[#[:space:]]*include\s+\./kitty-themes/.*\.conf' "$temp_kitty_config_file"; then
    sed -i -E "s|^([#[:space:]]*include\s+\./kitty-themes/).*\.conf|include ./kitty-themes/$theme_name_to_apply.conf|g" "$temp_kitty_config_file"
  else
    if [ -s "$temp_kitty_config_file" ] && [ "$(tail -c1 "$temp_kitty_config_file")" != "" ]; then
      echo >>"$temp_kitty_config_file"
    fi
    echo "include ./kitty-themes/$theme_name_to_apply.conf" >>"$temp_kitty_config_file"
  fi

  cp "$temp_kitty_config_file" "$kitty_config"
  rm "$temp_kitty_config_file"

  for pid_kitty in $(pidof kitty); do
    if [ -n "$pid_kitty" ]; then
      kill -SIGUSR1 "$pid_kitty"
    fi
  done
  return 0
}

# Function to generate a btop theme from a kitty theme
generate_btop_theme() {
  local theme_name="$1"
  local kitty_file="$kitty_themes_DiR/$theme_name.conf"
  local btop_theme_dir="$HOME/.config/btop/themes"
  local btop_theme_file="$btop_theme_dir/kitty-colors.theme"

  mkdir -p "$btop_theme_dir"

  if [ ! -f "$kitty_file" ]; then
    echo "btop: Kitty theme not found: $kitty_file"
    return 1
  fi

  get_color() {
    grep -i "^$1" "$kitty_file" | awk '{print $2}' | head -n1
  }

  bg=$(get_color background)
  fg=$(get_color foreground)

  c0=$(get_color color0)
  c1=$(get_color color1)
  c2=$(get_color color2)
  c3=$(get_color color3)
  c4=$(get_color color4)
  c5=$(get_color color5)
  c6=$(get_color color6)
  c7=$(get_color color7)

  bg=${bg:-"#1e1e2e"}
  fg=${fg:-"#cdd6f4"}
  c1=${c1:-"#f38ba8"}
  c2=${c2:-"#a6e3a1"}
  c3=${c3:-"#f9e2af"}
  c4=${c4:-"#89b4fa"}
  c5=${c5:-"#cba6f7"}
  c6=${c6:-"#94e2d5"}
  c7=${c7:-"#bac2de"}

  cat > "$btop_theme_file" <<EOF
theme[main_bg]="$bg"
theme[main_fg]="$fg"
theme[title]="$fg"
theme[hi_fg]="$c4"

theme[selected_bg]="$c0"
theme[selected_fg]="$c4"
theme[inactive_fg]="$c7"

theme[graph_text]="$c3"
theme[meter_bg]="$c0"
theme[proc_misc]="$c3"

theme[cpu_box]="$c4"
theme[mem_box]="$c2"
theme[net_box]="$c5"
theme[proc_box]="$c1"

theme[div_line]="$c7"

theme[temp_start]="$c3"
theme[temp_mid]="$c5"
theme[temp_end]="$c1"

theme[cpu_start]="$c4"
theme[cpu_mid]="$c6"
theme[cpu_end]="$c2"

theme[free_start]="$c2"
theme[free_mid]="$c2"
theme[free_end]="$c6"

theme[cached_start]="$c5"
theme[cached_mid]="$c5"
theme[cached_end]="$c4"

theme[available_start]="$c3"
theme[available_mid]="$c1"
theme[available_end]="$c1"

theme[used_start]="$c5"
theme[used_mid]="$c5"
theme[used_end]="$c1"

theme[download_start]="$c4"
theme[download_mid]="$c4"
theme[download_end]="$c5"

theme[upload_start]="$c4"
theme[upload_mid]="$c4"
theme[upload_end]="$c5"

theme[process_start]="$c4"
theme[process_mid]="$c6"
theme[process_end]="$c2"
EOF

  echo "btop theme updated: kitty-colors.theme"
}

# --- Main Script Execution ---

if [ ! -d "$kitty_themes_DiR" ]; then
  notify_user "$iDIR/error.png" "E-R-R-O-R" "Kitty Themes directory not found: $kitty_themes_DiR"
  exit 1
fi

if [ ! -f "$rofi_theme_for_this_script" ]; then
  notify_user "$iDIR/error.png" "Rofi Config Missing" "Rofi theme for Kitty selector not found at: $rofi_theme_for_this_script."
  exit 1
fi

original_kitty_config_content_backup=$(cat "$kitty_config")

mapfile -t available_theme_names < <(find "$kitty_themes_DiR" -maxdepth 1 -name "*.conf" -type f -printf "%f\n" | sed 's/\.conf$//' | sort)

if [ ${#available_theme_names[@]} -eq 0 ]; then
  notify_user "$iDIR/error.png" "No Kitty Themes" "No .conf files found in $kitty_themes_DiR."
  exit 1
fi

current_selection_index=0
current_active_theme_name=$(awk -F'include ./kitty-themes/|\\.conf' '/^[[:space:]]*include \.\/kitty-themes\/.*\.conf/{print $2; exit}' "$kitty_config")

if [ -n "$current_active_theme_name" ]; then
  for i in "${!available_theme_names[@]}"; do
    if [[ "${available_theme_names[$i]}" == "$current_active_theme_name" ]]; then
      current_selection_index=$i
      break
    fi
  done
fi

while true; do
  theme_to_preview_now="${available_theme_names[$current_selection_index]}"

  if ! apply_kitty_theme_to_config "$theme_to_preview_now"; then
    echo "$original_kitty_config_content_backup" >"$kitty_config"
    for pid_kitty in $(pidof kitty); do if [ -n "$pid_kitty" ]; then kill -SIGUSR1 "$pid_kitty"; fi; done
    notify_user "$iDIR/error.png" "Preview Error" "Failed to apply $theme_to_preview_now. Reverted."
    exit 1
  fi

  rofi_input_list=""
  for theme_name_in_list in "${available_theme_names[@]}"; do
    rofi_input_list+="$theme_name_in_list\n"
  done
  rofi_input_list_trimmed="${rofi_input_list%\\n}"

  chosen_index_from_rofi=$(echo -e "$rofi_input_list_trimmed" |
    rofi -dmenu -i \
      -format 'i' \
      -p "Kitty Theme" \
      -mesg "Preview: ${theme_to_preview_now} | Enter: Preview | Ctrl+S: Apply & Exit | Esc: Cancel" \
      -config "$rofi_theme_for_this_script" \
      -selected-row "$current_selection_index" \
      -kb-custom-1 "Control+s") # MODIFIED HERE: Changed to Control+s for custom action 1

  rofi_exit_code=$?

  if [ $rofi_exit_code -eq 0 ]; then
    if [[ "$chosen_index_from_rofi" =~ ^[0-9]+$ ]] && [ "$chosen_index_from_rofi" -lt "${#available_theme_names[@]}" ]; then
      current_selection_index="$chosen_index_from_rofi"
    else
      :
    fi
  elif [ $rofi_exit_code -eq 1 ]; then
    notify_user "$iDIR/note.png" "Kitty Theme" "Selection cancelled. Reverting to original theme."
    echo "$original_kitty_config_content_backup" >"$kitty_config"
    for pid_kitty in $(pidof kitty); do if [ -n "$pid_kitty" ]; then kill -SIGUSR1 "$pid_kitty"; fi; done
    break
  elif [ $rofi_exit_code -eq 10 ]; then # This is the exit code for -kb-custom-1
    generate_btop_theme "$theme_to_preview_now"
    notify_user "$iDIR/ja.png" "Kitty Theme Applied" "$theme_to_preview_now"
    break
  else
    notify_user "$iDIR/error.png" "Rofi Error" "Unexpected Rofi exit ($rofi_exit_code). Reverting."
    echo "$original_kitty_config_content_backup" >"$kitty_config"
    for pid_kitty in $(pidof kitty); do if [ -n "$pid_kitty" ]; then kill -SIGUSR1 "$pid_kitty"; fi; done
    break
  fi
done

exit 0
