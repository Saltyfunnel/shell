#!/usr/bin/env bash
# install-sddm-theme.sh
#
# Optional extra for install-caelestia.sh: a minimal SDDM login theme that uses
# the Caelestia Material You colours (the Caelestia equivalent of pywal-sddm).
#
# Run as your normal user (needs sudo), after caelestia-cli is installed.
# Safe to re-run. To undo: sudo rm /etc/sddm.conf.d/10-theme.conf

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Run this as your normal user, not root." >&2
    exit 1
fi

if ! command -v caelestia &>/dev/null; then
    echo "caelestia-cli not found. Run install-caelestia.sh first." >&2
    exit 1
fi

sudo pacman -S --needed --noconfirm sddm jq

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
mkdir -p "$XDG_CONFIG_HOME/caelestia/templates"

# --- 7d. SDDM theme driven by the Caelestia scheme ---------------------------
# Same idea as the pywal-sddm theme, but colours come from Caelestia's Material
# You scheme. SDDM can't read your home directory, so a theme.conf is rendered by
# caelestia-cli (user template) and copied into the theme dir by a postHook
# whenever the scheme/wallpaper changes. The QML reads it as config.<name>.

echo "==> SDDM theme"
SDDM_THEME="caelestia"
SDDM_THEME_DIR="/usr/share/sddm/themes/$SDDM_THEME"

sudo mkdir -p "$SDDM_THEME_DIR" /etc/sddm.conf.d

# theme.conf is the only file the hook rewrites, so make just that file yours.
sudo tee "$SDDM_THEME_DIR/theme.conf" >/dev/null <<'EOF'
[General]
colorBg=#141218
colorSurface=#211f26
colorFg=#e6e0e9
colorAccent=#d0bcff
colorOnAccent=#381e72
colorOutline=#938f99
EOF
sudo chown "$USER" "$SDDM_THEME_DIR/theme.conf"

sudo tee "$SDDM_THEME_DIR/metadata.desktop" >/dev/null <<'EOF'
[SddmGreeterTheme]
Name=Caelestia
Description=Minimal login theme using the Caelestia Material You scheme
Author=Custom
Type=sddm-theme
MainScript=Main.qml
ConfigFile=theme.conf
QtVersion=6
EOF

sudo tee "$SDDM_THEME_DIR/Main.qml" >/dev/null <<'EOF'
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    color: config.colorBg

    Connections {
        target: sddm
        function onLoginFailed() {
            passwordInput.text = ""
            passwordInput.forceActiveFocus()
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 360
        height: 380
        radius: 16
        color: config.colorSurface
        border.color: config.colorOutline
        border.width: 1

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - 60
            spacing: 20

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 72
                height: 72
                radius: 36
                color: config.colorAccent

                Text {
                    anchors.centerIn: parent
                    text: usernameInput.text.length > 0 ? usernameInput.text.substring(0, 1).toUpperCase() : "?"
                    color: config.colorOnAccent
                    font.pixelSize: 32
                    font.bold: true
                    font.family: "Rubik"
                }
            }

            TextField {
                id: usernameInput
                Layout.fillWidth: true
                placeholderText: "Username"
                text: userModel.lastUser
                color: config.colorFg
                font.family: "Rubik"
                font.pixelSize: 14
                background: Rectangle {
                    color: config.colorBg
                    radius: 8
                    border.width: 1
                    border.color: usernameInput.activeFocus ? config.colorAccent : config.colorOutline
                }
            }

            TextField {
                id: passwordInput
                Layout.fillWidth: true
                placeholderText: "Password"
                echoMode: TextInput.Password
                focus: true
                color: config.colorFg
                font.family: "Rubik"
                font.pixelSize: 14
                background: Rectangle {
                    color: config.colorBg
                    radius: 8
                    border.width: 1
                    border.color: passwordInput.activeFocus ? config.colorAccent : config.colorOutline
                }
                onAccepted: sddm.login(usernameInput.text, passwordInput.text, sessionSelect.currentIndex)
            }

            ComboBox {
                id: sessionSelect
                Layout.fillWidth: true
                model: sessionModel
                textRole: "name"
                currentIndex: sessionModel.lastIndex
                font.family: "Rubik"
                font.pixelSize: 12
                contentItem: Text {
                    leftPadding: 10
                    text: sessionSelect.displayText
                    color: config.colorFg
                    font: sessionSelect.font
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: config.colorBg
                    radius: 8
                    border.width: 1
                    border.color: config.colorOutline
                }
            }

            Button {
                Layout.fillWidth: true
                height: 40
                onClicked: sddm.login(usernameInput.text, passwordInput.text, sessionSelect.currentIndex)
                contentItem: Text {
                    text: "LOGIN"
                    color: config.colorOnAccent
                    font.bold: true
                    font.family: "Rubik"
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.down ? Qt.darker(config.colorAccent, 1.2) : config.colorAccent
                    radius: 8
                }
            }
        }
    }
}
EOF

sudo tee /etc/sddm.conf.d/10-theme.conf >/dev/null <<EOF
[Theme]
Current=$SDDM_THEME
EOF

# caelestia-cli template -> rendered into ~/.local/state/caelestia/theme/
cat > "$XDG_CONFIG_HOME/caelestia/templates/sddm-theme.conf" <<'EOF'
[General]
colorBg=#{{ background.hex }}
colorSurface=#{{ surface.hex }}
colorFg=#{{ onSurface.hex }}
colorAccent=#{{ primary.hex }}
colorOnAccent=#{{ onPrimary.hex }}
colorOutline=#{{ outline.hex }}
EOF

# postHook: copy the rendered file into the theme after every scheme change.
# Only set if you don't already have one in cli.json.
SDDM_HOOK="cp -f $HOME/.local/state/caelestia/theme/sddm-theme.conf $SDDM_THEME_DIR/theme.conf"
CLI_JSON="$XDG_CONFIG_HOME/caelestia/cli.json"
if [[ -f "$CLI_JSON" ]]; then
    jq --arg h "$SDDM_HOOK" '.theme.postHook //= $h' "$CLI_JSON" > "$CLI_JSON.tmp" \
        && mv "$CLI_JSON.tmp" "$CLI_JSON"
else
    jq -n --arg h "$SDDM_HOOK" '{theme: {postHook: $h}}' > "$CLI_JSON"
fi

# If a scheme has already been generated, apply its colours right away.
RENDERED="$HOME/.local/state/caelestia/theme/sddm-theme.conf"
if [[ -f "$RENDERED" ]]; then
    cp -f "$RENDERED" "$SDDM_THEME_DIR/theme.conf"
fi

echo
echo "==> Done. The theme shows at your next login screen (log out or reboot)."
echo "    Colours update whenever you change the wallpaper or scheme."
echo "    Until the first scheme change you get a default dark Material palette."
