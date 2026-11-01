import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    width: 1920
    height: 1080

    // Default fallback colors (Material Design dark theme defaults)
    property color colorBg: "#1e1e2e"
    property color colorFg: "#cdd6f4"
    property color colorAccent: "#89b4fa"
    property color colorInputBg: "#11111b"

    // Written by matugen on every wallpaper change (see matugen/config.toml)
    readonly property string materialJsonPath: "file:///var/cache/wal/colors.json"

    function loadMaterialColors() {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", root.materialJsonPath, true);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200 || xhr.status === 0) {
                    try {
                        var colors = JSON.parse(xhr.responseText);

                        // Support Material structures (special/colors or direct keys)
                        if (colors.special) {
                            root.colorBg = colors.special.background || root.colorBg;
                            root.colorFg = colors.special.foreground || root.colorFg;
                        } else if (colors.background) {
                            root.colorBg = colors.background;
                        }

                        if (colors.colors) {
                            root.colorAccent = colors.colors.color4 || colors.colors.primary || root.colorAccent;
                            root.colorInputBg = colors.colors.color0 || colors.colors.surface || root.colorInputBg;
                        } else {
                            if (colors.primary) root.colorAccent = colors.primary;
                            if (colors.surface) root.colorInputBg = colors.surface;
                        }
                    } catch (e) {
                        console.log("Failed to parse Material JSON, using fallback colors.");
                    }
                }
            }
        };
        xhr.send();
    }

    Component.onCompleted: {
        loadMaterialColors();
    }

    color: root.colorBg

    // Center Card Container
    Rectangle {
        anchors.centerIn: parent
        width: 360
        height: 380
        radius: 16
        color: Qt.rgba(root.colorInputBg.r, root.colorInputBg.g, root.colorInputBg.b, 0.6)
        border.color: root.colorAccent
        border.width: 1

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 20
            width: parent.width - 60

            // User Avatar / Icon Indicator
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 72
                height: 72
                radius: 36
                color: root.colorAccent

                Text {
                    anchors.centerIn: parent
                    text: usernameInput.text.length > 0 ? usernameInput.text.substring(0, 1).toUpperCase() : "?"
                    color: root.colorBg
                    font.pixelSize: 32
                    font.bold: true
                    font.family: "Hack Nerd Font"
                }
            }

            // Username Input Field
            TextField {
                id: usernameInput
                Layout.fillWidth: true
                placeholderText: "Username"
                text: userModel.lastUser
                font.family: "Hack Nerd Font"
                font.pixelSize: 14
                color: root.colorFg
                background: Rectangle {
                    color: Qt.darker(root.colorInputBg, 1.2)
                    radius: 8
                    border.color: usernameInput.activeFocus ? root.colorAccent : "transparent"
                    border.width: 1
                }
            }

            // Password Input Field
            TextField {
                id: passwordInput
                Layout.fillWidth: true
                placeholderText: "Password"
                echoMode: TextInput.Password
                font.family: "Hack Nerd Font"
                font.pixelSize: 14
                color: root.colorFg
                focus: true
                background: Rectangle {
                    color: Qt.darker(root.colorInputBg, 1.2)
                    radius: 8
                    border.color: passwordInput.activeFocus ? root.colorAccent : "transparent"
                    border.width: 1
                }
                onAccepted: sddm.login(usernameInput.text, passwordInput.text, sessionSelect.currentIndex)
            }

            // Session Selector
            ComboBox {
                id: sessionSelect
                Layout.fillWidth: true
                model: sessionModel
                textRole: "name"
                currentIndex: sessionModel.lastIndex
                font.family: "Hack Nerd Font"
                font.pixelSize: 12
            }

            // Login Button
            Button {
                Layout.fillWidth: true
                height: 40
                onClicked: sddm.login(usernameInput.text, passwordInput.text, sessionSelect.currentIndex)

                contentItem: Text {
                    text: "LOGIN"
                    color: root.colorBg
                    font.bold: true
                    font.family: "Hack Nerd Font"
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    color: parent.down ? Qt.darker(root.colorAccent, 1.2) : root.colorAccent
                    radius: 8
                }
            }
        }
    }

    // Power buttons (bottom-right)
    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 24
        spacing: 12

        Button {
            id: rebootBtn
            visible: sddm.canReboot
            width: 40
            height: 40
            hoverEnabled: true
            onClicked: sddm.reboot()

            ToolTip.visible: hovered
            ToolTip.text: "Reboot"

            contentItem: Text {
                text: "\uf021"
                color: rebootBtn.hovered ? root.colorBg : root.colorFg
                font.family: "Hack Nerd Font"
                font.pixelSize: 18
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                radius: 8
                color: rebootBtn.hovered ? root.colorAccent : Qt.rgba(root.colorInputBg.r, root.colorInputBg.g, root.colorInputBg.b, 0.6)
                border.color: root.colorAccent
                border.width: 1
            }
        }

        Button {
            id: powerBtn
            visible: sddm.canPowerOff
            width: 40
            height: 40
            hoverEnabled: true
            onClicked: sddm.powerOff()

            ToolTip.visible: hovered
            ToolTip.text: "Shut down"

            contentItem: Text {
                text: "\uf011"
                color: powerBtn.hovered ? root.colorBg : root.colorFg
                font.family: "Hack Nerd Font"
                font.pixelSize: 18
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                radius: 8
                color: powerBtn.hovered ? root.colorAccent : Qt.rgba(root.colorInputBg.r, root.colorInputBg.g, root.colorInputBg.b, 0.6)
                border.color: root.colorAccent
                border.width: 1
            }
        }
    }
}
