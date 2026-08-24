/*
 * SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Style
import "../../tray"

Control {
    id: root

    property alias title: titleLabel.text
    property alias description: descriptionLabel.text
    property string iconSource: ""
    property bool selected: false
    readonly property color primaryTextColor: Style.wizardPrimaryText
    readonly property color hintTextColor: Style.wizardSecondaryText

    signal clicked()

    hoverEnabled: true
    implicitHeight: descriptionLabel.text === "" ? 46 : 60
    padding: 12

    scale: mouseArea.pressed && root.enabled ? 0.99 : 1.0
    Behavior on scale {
        NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
    }

    background: Rectangle {
        radius: 10
        border.width: root.selected ? 2 : 1
        border.color: !root.enabled
            ? Style.wizardRowDisabledBorder
            : root.selected
                ? Style.ncBlue
                : (root.hovered ? Style.ncBlue : Style.wizardRowBorder)
        color: !root.enabled ? Style.wizardRowDisabledBackground : root.selected
            ? Style.wizardSelectedBackground
            : (root.hovered ? Qt.lighter(Style.wizardRowBackground, 1.04) : Style.wizardRowBackground)

        Behavior on border.color {
            ColorAnimation { duration: 120 }
        }
        Behavior on color {
            ColorAnimation { duration: 120 }
        }
    }

    contentItem: RowLayout {
        spacing: 10

        Rectangle {
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            Layout.alignment: Qt.AlignVCenter
            radius: width / 2
            border.width: 2
            border.color: root.enabled ? Style.wizardRadioAccent : Style.wizardRadioDisabled
            color: "transparent"

            Behavior on border.color {
                ColorAnimation { duration: 120 }
            }

            Rectangle {
                anchors.centerIn: parent
                width: 8
                height: 8
                radius: width / 2
                color: Style.wizardRadioAccent
                scale: root.selected && root.enabled ? 1.0 : 0.0
                opacity: root.selected && root.enabled ? 1.0 : 0.0

                Behavior on scale {
                    NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 4 }
                }
                Behavior on opacity {
                    NumberAnimation { duration: 120 }
                }
            }
        }

        ColumnLayout {
            spacing: 0
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            EnforcedPlainTextLabel {
                id: titleLabel
                Layout.fillWidth: true
                color: root.enabled ? root.primaryTextColor : root.hintTextColor
                font.bold: true
                font.pixelSize: Style.pixelSize + 1
                elide: Text.ElideRight
            }

            EnforcedPlainTextLabel {
                id: descriptionLabel
                visible: text !== ""
                Layout.fillWidth: true
                color: root.hintTextColor
                font.pixelSize: Style.pixelSize
                wrapMode: Text.WordWrap
                maximumLineCount: 2
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
