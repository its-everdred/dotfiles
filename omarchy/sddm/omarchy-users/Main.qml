import QtQuick 2.0
import SddmComponents 2.0

// Omarchy login theme with a user picker. Colours #1a1b26 / #ffffff are
// placeholders that install.sh swaps for the current Omarchy theme's colours.
Rectangle {
  id: root
  width: 640
  height: 480
  color: "#1a1b26"

  readonly property color textColor: "#ffffff"
  readonly property color failColor: "#f7768e"
  readonly property string assets: "../omarchy/"

  property string currentUser: ""
  property bool loginFailed: false
  property int sessionIndex: {
    for (var i = 0; i < sessionModel.rowCount(); i++) {
      var name = (sessionModel.data(sessionModel.index(i, 0), Qt.DisplayRole) || "").toString()
      if (name.indexOf("uwsm") !== -1)
        return i
    }
    return sessionModel.lastIndex
  }

  function selectUser(name) {
    currentUser = name
    loginFailed = false
    password.text = ""
    password.forceActiveFocus()
  }

  function backToPicker() {
    currentUser = ""
    loginFailed = false
    password.text = ""
    picker.forceActiveFocus()
  }

  Connections {
    target: sddm
    function onLoginFailed() {
      password.text = "" // before loginFailed: clearing text fires onTextChanged, which resets it
      root.loginFailed = true
      password.focus = true
    }
    function onLoginSucceeded() {
      root.loginFailed = false
    }
  }

  Column {
    anchors.centerIn: parent
    spacing: 40

    Image {
      id: logo
      source: root.assets + "logo.png"
      width: Math.min(sourceSize.width, root.width * 0.8)
      height: sourceSize.width > 0 ? Math.round(width * sourceSize.height / sourceSize.width) : 0
      fillMode: Image.PreserveAspectFit
      anchors.horizontalCenter: parent.horizontalCenter
    }

    FocusScope {
      id: picker
      anchors.horizontalCenter: parent.horizontalCenter
      width: tiles.width
      height: tiles.height
      focus: true

      property int focusIndex: 0

      Keys.onPressed: {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
          focusIndex = Math.max(0, focusIndex - 1)
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
          focusIndex = Math.min(users.count - 1, focusIndex + 1)
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
          root.selectUser(users.itemAt(focusIndex).userName)
        } else {
          return
        }
        event.accepted = true
      }

      Row {
        id: tiles
        spacing: 40

        Repeater {
          id: users
          model: userModel

          Column {
            id: tile
            spacing: 14

            property string userName: model.name
            property bool chosen: root.currentUser === model.name
            property bool keyFocus: picker.activeFocus && picker.focusIndex === index
            opacity: root.currentUser === "" || chosen ? 1 : 0.4

            Component.onCompleted: if (model.name === userModel.lastUser) picker.focusIndex = index

            Rectangle {
              width: 120
              height: 120
              color: "transparent"
              border.color: root.textColor
              border.width: tile.chosen || tile.keyFocus || mouse.containsMouse ? 3 : 1
              anchors.horizontalCenter: parent.horizontalCenter

              Image {
                id: face
                anchors.fill: parent
                anchors.margins: 6
                source: model.icon
                fillMode: Image.PreserveAspectCrop
                // SDDM's fallback silhouette is near-invisible on dark backgrounds; only show
                // a real face (faces/<name>.face.icon or /home/<name>/.face.icon).
                visible: status === Image.Ready && String(model.icon).indexOf(model.name) !== -1
              }

              Text {
                anchors.centerIn: parent
                visible: !face.visible
                text: "\uf007" // Nerd Font user icon
                color: root.textColor
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 64
              }

              MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  picker.focusIndex = index
                  root.selectUser(model.name)
                }
              }
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: model.realName !== "" ? model.realName : model.name
              color: root.textColor
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 18
            }
          }
        }
      }
    }

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 15
      visible: root.currentUser !== ""

      Image {
        source: root.assets + (root.loginFailed ? "lock-failed.png" : "lock.png")
        width: 34
        height: 38
        fillMode: Image.PreserveAspectFit
        anchors.verticalCenter: parent.verticalCenter
      }

      Item {
        width: entry.width
        height: entry.height

        Image {
          id: entry
          source: root.assets + (root.loginFailed ? "entry-failed.png" : "entry.png")
          anchors.centerIn: parent
        }

        Row {
          anchors.left: parent.left
          anchors.leftMargin: 20
          anchors.verticalCenter: parent.verticalCenter
          spacing: 5

          Repeater {
            model: Math.min(password.text.length, 21)

            Image {
              source: root.assets + "bullet.png"
              width: 7
              height: 7
            }
          }
        }

        TextInput {
          id: password
          anchors.fill: parent
          anchors.leftMargin: 20
          anchors.rightMargin: 20
          verticalAlignment: TextInput.AlignVCenter
          echoMode: TextInput.Password
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 24
          font.letterSpacing: 5
          passwordCharacter: "•"
          color: "transparent"
          selectionColor: "transparent"
          selectedTextColor: "transparent"
          cursorDelegate: Item {}

          onTextChanged: root.loginFailed = false

          Keys.onPressed: {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              sddm.login(root.currentUser, password.text, root.sessionIndex)
              event.accepted = true
            } else if (event.key === Qt.Key_Escape) {
              root.backToPicker()
              event.accepted = true
            }
          }
        }
      }
    }
  }

  Component.onCompleted: picker.forceActiveFocus()
}
