/*
 * SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Style
import "../../tray"

Item {
    id: root

    required property QtObject controller
    property string descriptionText: ""
    readonly property color primaryTextColor: Style.wizardPrimaryText
    readonly property color primaryButtonColor: Style.wizardPrimaryButtonBackground

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        Item {
            Layout.fillHeight: true
        }

        Rectangle {
            id: badge
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 96
            Layout.preferredHeight: 96
            radius: 24
            clip: true

            readonly property color gradientTop: Style.darkMode
                ? Qt.lighter(Style.ncBlue, 1.15)
                : Qt.lighter(Style.ncBlue, 1.35)
            readonly property color gradientBottom: Qt.darker(Style.ncBlue, 1.1)

            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: badge.gradientTop }
                GradientStop { position: 1.0; color: badge.gradientBottom }
            }

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.22)
                shadowBlur: 0.6
                shadowVerticalOffset: 5
            }

            scale: 0.5
            opacity: 0
            Component.onCompleted: badgeEntrance.start()
            ParallelAnimation {
                id: badgeEntrance
                NumberAnimation {
                    target: badge
                    property: "scale"
                    from: 0.5
                    to: 1.0
                    duration: 340
                    easing.type: Easing.OutBack
                    easing.overshoot: 5
                }
                NumberAnimation {
                    target: badge
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                id: logoTile
                anchors.centerIn: parent
                width: 60
                height: 60
                radius: 15
                color: Style.wizardWindowBackground
                clip: true

                Image {
                    anchors.fill: parent
                    anchors.margins: 4
                    source: "qrc:/client/theme/colored/company-logo.jpg"
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    asynchronous: true

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: logoMask
                    }
                }

                Rectangle {
                    id: logoMask
                    anchors.fill: parent
                    radius: 11
                    visible: false
                    layer.enabled: true
                }
            }
        }

        EnforcedPlainTextLabel {
            text: qsTr("Switch to your browser")
            color: root.primaryTextColor
            font.pixelSize: Style.pixelSize + 8
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        EnforcedPlainTextLabel {
            visible: root.descriptionText.length > 0
            text: root.descriptionText
            color: Style.wizardSecondaryText
            font.pixelSize: Style.wizardBodyFontPixelSize
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        RowLayout {
            id: activityIndicatorRow

            visible: root.controller.busy || root.controller.authPolling
            spacing: 8
            Layout.fillWidth: true
            Layout.topMargin: 4

            Item {
                Layout.fillWidth: true
            }

            NCBusyIndicator {
                running: activityIndicatorRow.visible
                visible: running
                color: Style.ncBlue
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
            }

            Item {
                Layout.fillWidth: true
            }
        }

        EnforcedPlainTextLabel {
            visible: root.controller.errorText.length > 0
            text: root.controller.errorText
            color: Style.wizardErrorText
            font.pixelSize: Style.pixelSize + 1
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
