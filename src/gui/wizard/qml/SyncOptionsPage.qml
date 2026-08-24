/*
 * SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Style
import com.nextcloud.desktopclient
import "../../tray"

Item {
    id: root

    required property var controller
    readonly property string serverLabel: root.controller.serverDisplayName !== ""
        ? root.controller.serverDisplayName
        : root.controller.serverUrl.replace(/^https?:\/\//, "").replace(/\/$/, "")
    readonly property color primaryTextColor: Style.wizardPrimaryText
    readonly property color hintTextColor: Style.wizardSecondaryText

    opacity: 0
    Component.onCompleted: pageEntrance.start()
    NumberAnimation {
        id: pageEntrance
        target: root
        property: "opacity"
        from: 0
        to: 1
        duration: 260
        easing.type: Easing.OutCubic
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 28
        anchors.rightMargin: 28
        anchors.topMargin: 40
        anchors.bottomMargin: 16
        spacing: Style.extraSmallSpacing

        Item {
            id: avatarRing
            Layout.preferredWidth: 88
            Layout.preferredHeight: 88
            Layout.alignment: Qt.AlignHCenter

            scale: 0.6
            opacity: 0
            Component.onCompleted: avatarEntrance.start()
            ParallelAnimation {
                id: avatarEntrance
                NumberAnimation {
                    target: avatarRing
                    property: "scale"
                    from: 0.6
                    to: 1.0
                    duration: 340
                    easing.type: Easing.OutBack
                    easing.overshoot: 5
                }
                NumberAnimation {
                    target: avatarRing
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 260
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2

                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: Qt.lighter(Style.ncBlue, 1.3) }
                    GradientStop { position: 1.0; color: Qt.darker(Style.ncBlue, 1.1) }
                }

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Qt.rgba(Style.ncBlue.r, Style.ncBlue.g, Style.ncBlue.b, 0.35)
                    shadowBlur: 0.6
                    shadowVerticalOffset: 3
                }
            }

            Item {
                anchors.fill: parent
                anchors.margins: 4

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Style.wizardAvatarPlaceholder
                    visible: accountAvatar.status !== Image.Ready
                    clip: true

                    EnforcedPlainTextLabel {
                        anchors.centerIn: parent
                        text: root.controller.userDisplayName !== "" ? root.controller.userDisplayName.charAt(0).toUpperCase() : ""
                        color: root.primaryTextColor
                        font.pixelSize: Style.pixelSize + 20
                        font.bold: true
                    }
                }

                Image {
                    id: accountAvatar
                    anchors.fill: parent
                    source: root.controller.avatarUrl
                    sourceSize.width: 80
                    sourceSize.height: 80
                    fillMode: Image.PreserveAspectCrop
                    cache: false
                    visible: status === Image.Ready

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: avatarMask
                    }
                }

                Rectangle {
                    id: avatarMask
                    anchors.fill: parent
                    radius: width / 2
                    visible: false
                    layer.enabled: true
                }
            }
        }

        EnforcedPlainTextLabel {
            text: root.controller.userDisplayName
            color: root.primaryTextColor
            font.pixelSize: Style.pixelSize + 6
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
            Layout.topMargin: 12
            wrapMode: Text.WordWrap
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
            Layout.preferredWidth: serverLabelText.implicitWidth + 20
            Layout.preferredHeight: serverLabelText.implicitHeight + 8
            radius: height / 2
            color: Style.wizardRowBackground
            border.width: 1
            border.color: Style.wizardRowBorder

            EnforcedPlainTextLabel {
                id: serverLabelText
                anchors.centerIn: parent
                text: root.serverLabel
                color: root.hintTextColor
                font.pixelSize: Style.pixelSize + 1
                elide: Text.ElideMiddle
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: 24
            spacing: 8

            OptionRow {
                Layout.fillWidth: true
                visible: root.controller.canUseVirtualFiles
                title: root.controller.isUsingFileProvider ? qsTr("File Provider") : qsTr("Virtual files")
                description: qsTr("Download files on-demand")
                selected: root.controller.syncMode === AccountWizardController.VirtualFiles
                onClicked: root.controller.setSyncMode(AccountWizardController.VirtualFiles)
            }

            OptionRow {
                Layout.fillWidth: true
                enabled: root.controller.canUseClassicSync
                title: qsTr("Synchronize everything")
                description: root.controller.syncEverythingDescription
                selected: root.controller.syncMode === AccountWizardController.SyncEverything
                onClicked: root.controller.setSyncMode(AccountWizardController.SyncEverything)
            }

            OptionRow {
                Layout.fillWidth: true
                enabled: root.controller.canUseClassicSync
                title: qsTr("Choose what to sync")
                description: ""
                selected: root.controller.syncMode === AccountWizardController.SelectiveSync
                onClicked: root.controller.openSelectiveSync()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: 18
            spacing: 6
            visible: root.controller.localSyncFolderRequired

            EnforcedPlainTextLabel {
                text: qsTr("Local sync folder")
                color: root.primaryTextColor
                font.pixelSize: Style.pixelSize + 1
                font.bold: true
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.wizardFooterButtonHeight
                    radius: 10
                    border.width: 1
                    border.color: root.controller.localSyncFolderError === "" ? Style.wizardRowBorder : Style.wizardErrorBorder
                    color: Style.wizardRowBackground

                    Behavior on border.color {
                        ColorAnimation { duration: 120 }
                    }

                    EnforcedPlainTextLabel {
                        anchors.fill: parent
                        anchors.leftMargin: Style.standardSpacing
                        anchors.rightMargin: Style.standardSpacing
                        verticalAlignment: Text.AlignVCenter
                        text: root.controller.localSyncFolderDisplay
                        color: root.primaryTextColor
                        font.pixelSize: Style.pixelSize
                        elide: Text.ElideMiddle
                    }
                }

                WizardButton {
                    text: qsTr("Choose")
                    Layout.preferredWidth: 96
                    Layout.preferredHeight: Style.wizardFooterButtonHeight
                    enabled: root.controller.canUseClassicSync
                    onClicked: root.controller.chooseLocalSyncFolder()
                }
            }

            EnforcedPlainTextLabel {
                visible: root.controller.localSyncFolderFreeSpace !== ""
                text: root.controller.localSyncFolderFreeSpace
                color: root.hintTextColor
                font.pixelSize: Style.pixelSize
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            EnforcedPlainTextLabel {
                visible: root.controller.localSyncFolderError !== ""
                text: root.controller.localSyncFolderError
                color: Style.wizardErrorText
                font.pixelSize: Style.pixelSize
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                maximumLineCount: 2
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
