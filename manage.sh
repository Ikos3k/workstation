#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root. Exiting."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$SCRIPT_DIR"

HOME_FILES=(
    ".bash_profile"
    ".bashrc"
    ".tmux.conf"
    ".xinitrc"
    ".Xresources"
    ".gtkrc-2.0"
    ".config/gtk-3.0/settings.ini"
    ".config/qt6ct/qt6ct.conf"
    ".config/Kvantum/kvantum.kvconfig"
    ".config/Kvantum/KvGnomeDark#/KvGnomeDark#.kvconfig"
    ".config/i3/config"
    ".config/xfce4/xfconf/xfce-perchannel-xml/xfce4-terminal.xml"
    # ".config/Thunar/accels.scm"
    ".config/Thunar/uca.xml"
    ".config/alacritty/alacritty.toml"
    ".config/wezterm/wezterm.lua"
    ".config/xfce4/helpers.rc"
    ".config/zed/settings.json"
    ".config/micro/settings.json"
    ".config/pcmanfm/default/pcmanfm.conf"
    ".config/lazygit/config.yml"
    ".config/dunst/dunstrc"
    "scripts/volume.sh"
    "scripts/switch_audio_out.sh"
    "scripts/fix_nameserver.sh"
    "scripts/Linux-Gaming"
    ".config/sunshine/sunshine.conf"
)

SYSTEM_FILES=(
    "/etc/i3status.conf"
    "/etc/environment"
    "/usr/local/bin/unmount_device"
    "/usr/local/bin/mount_device"
)

PERMISSIONS_FILE="$DOTFILES_DIR/permissions.txt"

backup_dotfiles() {
    local SHOW_DIFFS=0
    local SAFE_MODE=0
    local USE_LINKS=0

    for ARG in "$@"; do
        case "$ARG" in
            -diff)
                SHOW_DIFFS=1
                ;;
            -safe)
                SAFE_MODE=1
                SHOW_DIFFS=1
                ;;
            *)
                echo "Unknown option: $ARG"
                echo "Usage: backup_dotfiles [-diff] [-safe]"
                exit 1
                ;;
        esac
    done

    echo "Executing backup with options: -diff=$SHOW_DIFFS, -safe=$SAFE_MODE, -link=$USE_LINKS"

    if [ -n "$SUDO_USER" ]; then
        USER_HOME=$(eval echo ~$SUDO_USER)
    else
        echo "SUDO_USER is not set. Exiting."
        exit 1
    fi

    echo "Backing up home directory dotfiles from $USER_HOME to $DOTFILES_DIR..."
    > "$PERMISSIONS_FILE"
    for FILE_PATTERN in "${HOME_FILES[@]}"; do
        for FILE in "$USER_HOME/$FILE_PATTERN"; do
            if [ -e "$FILE" ]; then
                RELATIVE_FILE="${FILE#$USER_HOME/}"
                TARGET_FILE="$DOTFILES_DIR/$RELATIVE_FILE"
                echo "Backing up $RELATIVE_FILE to $DOTFILES_DIR"
                mkdir -p "$DOTFILES_DIR/$(dirname "$RELATIVE_FILE")"

                if [ -L "$FILE" ]; then
                    LINK_TARGET=$(readlink "$FILE")
                    if [[ "$LINK_TARGET" == "$DOTFILES_DIR/"* ]]; then
                        echo "Skipping $RELATIVE_FILE as it is already linked to the target directory."
                        continue
                    fi
                fi

                if [ "$SHOW_DIFFS" -eq 1 ]; then
                    if [ ! -f "$TARGET_FILE" ]; then
                        echo "[!!!] $RELATIVE_FILE does not exist in the backup directory. It will be backed up for the first time."
                    fi
                    if [ -f "$TARGET_FILE" ]; then
                        if ! diff -q "$TARGET_FILE" "$FILE" >/dev/null; then
                            echo "Differences for $RELATIVE_FILE:"
                            diff -u --color=auto "$TARGET_FILE" "$FILE"
                        fi
                    fi
                fi

                if [ "$SAFE_MODE" -eq 1 ]; then
                    read -p "Do you want to backup $RELATIVE_FILE? [y/N] " answer
                    case "$answer" in
                        [yY][eE][sS]|[yY])
                            cp -r "$FILE" "$TARGET_FILE"
                            ;;
                        *)
                            echo "Skipped backing up $RELATIVE_FILE"
                            ;;
                    esac
                else
                    cp -r "$FILE" "$TARGET_FILE"
                fi
            else
                echo "No existing $FILE found in home directory."
            fi
        done
    done

    echo "Backing up system-wide configuration files to $DOTFILES_DIR..."
    for FILE in "${SYSTEM_FILES[@]}"; do
        if [ -f "$FILE" ]; then
            RELATIVE_PATH="${FILE#/}"
            TARGET_FILE="$DOTFILES_DIR/$RELATIVE_PATH"

            echo "Backing up $FILE to $DOTFILES_DIR"
            mkdir -p "$DOTFILES_DIR/$(dirname "$RELATIVE_PATH")"

            if [ -L "$FILE" ]; then
                LINK_TARGET=$(readlink "$FILE")
                if [[ "$LINK_TARGET" == "$DOTFILES_DIR/"* ]]; then
                    echo "Skipping $RELATIVE_PATH as it is already linked to the target directory."
                    continue
                fi
            fi

            if [ "$SHOW_DIFFS" -eq 1 ]; then
                if [ ! -f "$TARGET_FILE" ]; then
                    echo "[!!!] $RELATIVE_PATH does not exist in the backup directory. It will be backed up for the first time."
                fi
                if [ -f "$TARGET_FILE" ]; then
                    if ! diff -q "$TARGET_FILE" "$FILE" >/dev/null; then
                        echo "Differences for $RELATIVE_PATH:"
                        diff -u --color=auto "$TARGET_FILE" "$FILE"
                    fi
                fi
            fi

            if [ "$SAFE_MODE" -eq 1 ]; then
                read -p "Do you want to backup $FILE? [y/N] " answer
                case "$answer" in
                    [yY][eE][sS]|[yY])
                        cp -r "$FILE" "$TARGET_FILE"
                        ;;
                    *)
                        echo "Skipped backing up $RELATIVE_FILE"
                        ;;
                esac
            else
                cp -r "$FILE" "$TARGET_FILE"
            fi

            FILE_PERMISSIONS=$(stat -c "%a" "$FILE")
            echo "$FILE $FILE_PERMISSIONS" >> "$PERMISSIONS_FILE"
            cp -r "$FILE" "$TARGET_FILE"

            chown -R "$SUDO_USER:$SUDO_USER" "$DOTFILES_DIR/$(dirname "$RELATIVE_PATH")"
            chown "$SUDO_USER:$SUDO_USER" "$TARGET_FILE"
        else
            echo "No existing $FILE found in the system."
        fi
    done
    
    chown -R "$SUDO_USER:$SUDO_USER" "$(dirname "$PERMISSIONS_FILE")"
    chown "$SUDO_USER:$SUDO_USER" "$PERMISSIONS_FILE"
    echo "Backup complete!"
}

restore_dotfiles() {
    local SHOW_DIFFS=0
    local SAFE_MODE=0
    local USE_LINKS=0

    for ARG in "$@"; do
        case "$ARG" in
            -diff)
                SHOW_DIFFS=1
                ;;
            -safe)
                SAFE_MODE=1
                SHOW_DIFFS=1
                ;;
            -link)
                USE_LINKS=1
                ;;
            *)
                echo "Unknown option: $ARG"
                echo "Usage: restore_dotfiles [-diff] [-safe] [-link]"
                exit 1
                ;;
        esac
    done

    echo "Executing restore with options: -diff=$SHOW_DIFFS, -safe=$SAFE_MODE, -link=$USE_LINKS"

    if [ -n "$SUDO_USER" ]; then
        USER_HOME=$(eval echo ~$SUDO_USER)
    else
        echo "SUDO_USER is not set. Exiting."
        exit 1
    fi

    echo "Restoring home directory dotfiles from $DOTFILES_DIR to $USER_HOME..."
    for FILE_PATTERN in "${HOME_FILES[@]}"; do
        for FILE in "$DOTFILES_DIR/$FILE_PATTERN"; do
            if [ -e "$FILE" ]; then
                RELATIVE_FILE="${FILE#$DOTFILES_DIR/}"
                TARGET_FILE="$USER_HOME/$RELATIVE_FILE"

                if [ -L "$TARGET_FILE" ]; then
                    echo "Removing symlink for $RELATIVE_FILE"
                    rm "$TARGET_FILE"
                fi

                if [ "$SHOW_DIFFS" -eq 1 ] && [ -f "$TARGET_FILE" ]; then
                    if ! diff -q "$TARGET_FILE" "$FILE" >/dev/null; then
                        echo "Differences for $RELATIVE_FILE:"
                        diff -u --color=auto "$TARGET_FILE" "$FILE"
                    fi
                fi

                if [ "$SAFE_MODE" -eq 1 ]; then
                    read -p "Do you want to restore $RELATIVE_FILE? [y/N] " answer
                    case "$answer" in
                        [yY][eE][sS]|[yY])
                            echo "Restoring $RELATIVE_FILE to $USER_HOME"
                            mkdir -p "$USER_HOME/$(dirname "$RELATIVE_FILE")"
                            if [ "$USE_LINKS" -eq 1 ]; then
                                ln -sf "$FILE" "$TARGET_FILE"
                                echo "Symlink created: $TARGET_FILE -> $FILE"
                            else
                                cp -r "$FILE" "$TARGET_FILE"
                            fi
                            ;;
                        *)
                            echo "Skipped restoring $RELATIVE_FILE"
                            ;;
                    esac
                else
                    echo "Restoring $RELATIVE_FILE to $USER_HOME"
                    mkdir -p "$USER_HOME/$(dirname "$RELATIVE_FILE")"
                    if [ "$USE_LINKS" -eq 1 ]; then
                        ln -sf "$FILE" "$TARGET_FILE"
                        echo "Symlink created: $TARGET_FILE -> $FILE"
                    else
                        cp -r "$FILE" "$TARGET_FILE"
                    fi
                fi
            else
                echo "No $FILE found in $DOTFILES_DIR."
            fi
        done
    done

    echo "Restoring system-wide configuration files from $DOTFILES_DIR..."
    for FILE in "${SYSTEM_FILES[@]}"; do
        RELATIVE_PATH="${FILE#/}"
        if [ -f "$DOTFILES_DIR/$RELATIVE_PATH" ]; then
            if [ -L "$FILE" ]; then
                echo "Removing symlink for $RELATIVE_PATH"
                rm "$FILE"
            fi

            if [ "$SHOW_DIFFS" -eq 1 ] && [ -f "$FILE" ]; then
                if ! diff -q "$DOTFILES_DIR/$RELATIVE_PATH" "$FILE" >/dev/null; then
                    echo "Differences for $FILE:"
                    diff -u --color=auto "$DOTFILES_DIR/$RELATIVE_PATH" "$FILE"
                fi
            fi

            if [ "$SAFE_MODE" -eq 1 ]; then
                read -p "Do you want to restore $RELATIVE_PATH? [y/N] " answer
                case "$answer" in
                    [yY])
                        echo "Restoring $RELATIVE_PATH to $FILE"
                        mkdir -p "$(dirname "$FILE")"
                        if [ "$USE_LINKS" -eq 1 ]; then
                            ln -sf "$DOTFILES_DIR/$RELATIVE_PATH" "$FILE"
                            echo "Symlink created: $FILE -> $DOTFILES_DIR/$RELATIVE_PATH"
                        else
                            cp -r "$DOTFILES_DIR/$RELATIVE_PATH" "$FILE"
                        fi

                        ORIGINAL_PERMISSIONS=$(grep -m 1 "^$FILE " "$PERMISSIONS_FILE" | awk '{print $2}')
                        if [ -n "$ORIGINAL_PERMISSIONS" ]; then
                            chmod "$ORIGINAL_PERMISSIONS" "$FILE"
                        fi
                        ;;
                    *)
                        echo "Skipped restoring $RELATIVE_PATH"
                        ;;
                esac
            else
                echo "Restoring $RELATIVE_PATH to $FILE"
                mkdir -p "$(dirname "$FILE")"
                if [ "$USE_LINKS" -eq 1 ]; then
                    ln -sf "$DOTFILES_DIR/$RELATIVE_PATH" "$FILE"
                    echo "Symlink created: $FILE -> $DOTFILES_DIR/$RELATIVE_PATH"
                else
                    cp -r "$DOTFILES_DIR/$RELATIVE_PATH" "$FILE"
                fi

                ORIGINAL_PERMISSIONS=$(grep -m 1 "^$FILE " "$PERMISSIONS_FILE" | awk '{print $2}')
                if [ -n "$ORIGINAL_PERMISSIONS" ]; then
                    chmod "$ORIGINAL_PERMISSIONS" "$FILE"
                fi
            fi
        else
            echo "No $RELATIVE_PATH found in $DOTFILES_DIR."
        fi
    done
    echo "Restore complete!"
}

ACTION=""
OPTIONS=()

for ARG in "$@"; do
    case "$ARG" in
        backup|restore)
            ACTION="$ARG"
            ;;
        -diff|-safe|-link)
            OPTIONS+=("$ARG")
            ;;
        *)
            echo "Unknown argument: $ARG"
            echo "Usage: $0 <backup|restore [-link]> [-diff] [-safe]"
            exit 1
            ;;
    esac
done

if [ "$ACTION" == "backup" ]; then
    backup_dotfiles "${OPTIONS[@]}"
elif [ "$ACTION" == "restore" ]; then
    restore_dotfiles "${OPTIONS[@]}"
else
    echo "No valid action specified. Use 'backup' or 'restore'."
    echo "Usage: $0 <backup|restore [-link]> [-diff] [-safe]"
    echo " -diff  : Compare files and show differences during restore."
    echo " -safe  : Prompt for confirmation before restoring each file. Automatically shows diffs."
    echo " -link  : Use symbolic links instead of copying files during restore."
    exit 1
fi
