/*
 * SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic as BasicControls
import QtQuick.Effects
import Style

BasicControls.Button {
    id: root

    property bool primary: false
    property string iconSource: ""
    property bool iconBeforeText: false
    property string textSuffix: ""
    readonly property color primaryColor: Style.wizardPrimaryButtonBackground
    readonly property color primaryPressedColor: Style.wizardPrimaryButtonPressed
    readonly property color primaryHoverColor: Qt.lighter(Style.wizardPrimaryButtonBackground, 1.12)
    readonly property color primaryGradientTop: root.down
        ? Qt.darker(Style.ncBlue, 1.05)
        : (root.hovered ? Qt.lighter(Style.ncBlue, 1.3) : Qt.lighter(Style.ncBlue, 1.15))
    readonly property color primaryGradientBottom: root.down
        ? Qt.darker(Style.ncBlue, 1.2)
        : Qt.darker(Style.ncBlue, root.hovered ? 1.0 : 1.05)
    readonly property color secondaryColor: Style.wizardSecondaryButtonBackground
    readonly property color secondaryPressedColor: Style.wizardSecondaryButtonPressed
    readonly property color secondaryHoverColor: Qt.lighter(Style.wizardSecondaryButtonBackground, 1.06)
    readonly property color secondaryBorderColor: Style.wizardSecondaryButtonBorder
    readonly property color disabledColor: Style.wizardDisabledButtonBackground
    readonly property color disabledBorderColor: Style.wizardDisabledButtonBorder

    implicitHeight: Style.wizardFooterButtonHeight
    leftPadding: 18
    rightPadding: 18
    font.pixelSize: Style.pixelSize + 3
    font.weight: Font.Medium
    Accessible.role: Accessible.Button
    Accessible.name: textSuffix === "" ? text : text + " " + textSuffix
    hoverEnabled: true

    scale: root.down ? 0.97 : (root.hovered ? 1.02 : 1.0)
    Behavior on scale {
        NumberAnimation {
            duration: 120
            easing.type: Easing.OutCubic
        }
    }

    contentItem: Item {
        implicitWidth: contentRow.implicitWidth
        implicitHeight: contentRow.implicitHeight

        Row {
            id: contentRow

            anchors.centerIn: parent
            spacing: 6

            Image {
                visible: root.iconSource !== "" && root.iconBeforeText
                source: root.iconSource
                sourceSize.width: Style.smallIconSize
                sourceSize.height: Style.smallIconSize
                width: visible ? Style.smallIconSize : 0
                height: Style.smallIconSize
                anchors.verticalCenter: parent.verticalCenter
                fillMode: Image.PreserveAspectFit
            }

            Text {
                text: root.textSuffix === "" ? root.text : root.text + " " + root.textSuffix
                font: root.font
                color: root.enabled
                    ? (root.primary ? Style.wizardSelectedText : root.palette.buttonText)
                    : Style.wizardDisabledText
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
            }

            Image {
                visible: root.iconSource !== "" && !root.iconBeforeText
                source: root.iconSource
                sourceSize.width: Style.smallIconSize
                sourceSize.height: Style.smallIconSize
                width: visible ? Style.smallIconSize : 0
                height: Style.smallIconSize
                anchors.verticalCenter: parent.verticalCenter
                fillMode: Image.PreserveAspectFit
            }
        }
    }

    background: Rectangle {
        radius: root.primary ? 10 : Style.mediumRoundedButtonRadius
        border.width: root.primary ? 0 : 1
        border.color: root.enabled ? root.secondaryBorderColor : root.disabledBorderColor

        Behavior on border.color {
            ColorAnimation { duration: 120 }
        }

        color: {
            if (!root.enabled) {
                return root.disabledColor
            }
            if (root.primary) {
                return "transparent"
            }
            if (root.down) {
                return root.secondaryPressedColor
            }
            return root.hovered ? root.secondaryHoverColor : root.secondaryColor
        }

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        gradient: root.primary && root.enabled ? primaryGradient : null

        Gradient {
            id: primaryGradient
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: root.primaryGradientTop }
            GradientStop { position: 1.0; color: root.primaryGradientBottom }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: root.primary
                ? Qt.rgba(Style.ncBlue.r, Style.ncBlue.g, Style.ncBlue.b, root.enabled ? (root.hovered ? 0.45 : 0.32) : 0)
                : Qt.rgba(0, 0, 0, root.enabled ? (root.hovered ? 0.18 : 0.08) : 0)
            shadowBlur: root.primary ? 0.6 : 0.4
            shadowVerticalOffset: root.hovered && root.enabled ? (root.primary ? 4 : 2) : (root.primary ? 2 : 1)

            Behavior on shadowVerticalOffset {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
            Behavior on shadowColor {
                ColorAnimation { duration: 120 }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        enabled: root.enabled
        hoverEnabled: enabled
        cursorShape: Qt.PointingHandCursor
    }
}
