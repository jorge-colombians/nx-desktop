/*
 * SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

import QtQuick
import QtQuick.Controls.Basic as BasicControls
import QtQuick.Layouts
import QtQuick.Effects
import com.nextcloud.desktopclient
import Style
import "../../tray"

Item {
    id: root

    required property var controller
    readonly property color primaryTextColor: Style.wizardPrimaryText
    readonly property color hintTextColor: Style.wizardSecondaryText

    opacity: 0
    Component.onCompleted: entranceAnimation.start()

    NumberAnimation {
        id: entranceAnimation
        target: root
        property: "opacity"
        from: 0
        to: 1
        duration: 260
        easing.type: Easing.OutCubic
    }

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        anchors.leftMargin: Style.wizardWindowMargin
        anchors.rightMargin: Style.wizardWindowMargin
        anchors.topMargin: Style.wizardWindowMargin
        anchors.bottomMargin: Style.wizardWindowMargin
        spacing: 4

        Rectangle {
            id: heroCard
            Layout.fillWidth: true
            Layout.preferredHeight: heroColumn.implicitHeight + 36
            Layout.bottomMargin: 14
            radius: 22
            clip: true

            readonly property color gradientTop: Style.darkMode
                ? Qt.lighter(Style.ncBlue, 1.15)
                : Qt.lighter(Style.ncBlue, 1.35)
            readonly property color gradientMid: Style.darkMode
                ? Qt.lighter(Style.ncBlue, 1.0)
                : Qt.lighter(Style.ncBlue, 1.15)
            readonly property color gradientBottom: Qt.darker(Style.ncBlue, 1.1)

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: heroCard.gradientTop }
                GradientStop { position: 0.55; color: heroCard.gradientMid }
                GradientStop { position: 1.0; color: heroCard.gradientBottom }
            }

            scale: 0.97
            Component.onCompleted: heroEntrance.start()
            NumberAnimation {
                id: heroEntrance
                target: heroCard
                property: "scale"
                from: 0.97
                to: 1.0
                duration: 340
                easing.type: Easing.OutBack
                easing.overshoot: 4
            }

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.22)
                shadowBlur: 0.7
                shadowVerticalOffset: 6
                shadowHorizontalOffset: 0
            }

            ColumnLayout {
                id: heroColumn
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 18
                width: parent.width - 48
                spacing: 10

                Rectangle {
                    id: logoBadge
                    Layout.alignment: Qt.AlignHCenter
                    width: 60
                    height: 60
                    radius: 15
                    color: Style.wizardWindowBackground
                    clip: true

                    scale: 0.4
                    Component.onCompleted: logoEntrance.start()
                    SequentialAnimation {
                        id: logoEntrance
                        PauseAnimation { duration: 120 }
                        NumberAnimation {
                            target: logoBadge
                            property: "scale"
                            from: 0.4
                            to: 1.0
                            duration: 320
                            easing.type: Easing.OutBack
                            easing.overshoot: 6
                        }
                    }

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: Qt.rgba(0, 0, 0, 0.25)
                        shadowBlur: 0.5
                        shadowVerticalOffset: 2
                    }

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

                EnforcedPlainTextLabel {
                    text: qsTr("Log in to %1").arg("CMC")
                    color: Style.wizardSelectedText
                    font.pixelSize: Style.pixelSize + 10
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }

                EnforcedPlainTextLabel {
                    text: qsTr("Enter the link to your %1 web interface from the browser or the link to a folder shared with you.").arg("CMC")
                    color: Qt.rgba(1, 1, 1, 0.85)
                    font.pixelSize: Style.pixelSize + 2
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }
        }

        Item {
            id: inputRow
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            Layout.topMargin: 22

            Item {
                id: inputRowInner
                x: 0
                width: parent.width
                height: parent.height

                opacity: 0
                Component.onCompleted: inputRowEntrance.start()
                SequentialAnimation {
                    id: inputRowEntrance
                    PauseAnimation { duration: 160 }
                    ParallelAnimation {
                        NumberAnimation {
                            target: inputRowInner
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: 280
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            target: inputRowInner
                            property: "y"
                            from: 12
                            to: 0
                            duration: 280
                            easing.type: Easing.OutCubic
                        }
                    }
                }

            RowLayout {
                anchors.fill: parent
                anchors.topMargin: 6
                spacing: 8

                WizardTextField {
                    id: serverUrlField
                    visible: !root.controller.overrideServerSelectionRequired
                    Layout.fillWidth: true
                    text: root.controller.serverUrl
                    enabled: !root.controller.busy
                    readOnly: !root.controller.serverUrlEditable
                    placeholderText: root.controller.serverUrlPlaceholder
                    inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase
                    selectByMouse: true
                    onTextEdited: root.controller.serverUrl = text
                    onAccepted: root.controller.submitServerUrl()
                }

                BasicControls.ComboBox {
                    id: serverSelector

                    visible: root.controller.overrideServerSelectionRequired
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.standardPrimaryButtonHeight
                    implicitHeight: Style.standardPrimaryButtonHeight
                    model: root.controller.overrideServerNames
                    currentIndex: root.controller.overrideServerIndex
                    enabled: !root.controller.busy
                    font.pixelSize: Style.pixelSize + 3
                    onActivated: root.controller.overrideServerIndex = currentIndex

                    leftPadding: 12
                    rightPadding: 40
                    topPadding: 0
                    bottomPadding: 0

                    contentItem: Text {
                        text: serverSelector.displayText
                        font: serverSelector.font
                        color: serverSelector.enabled ? root.primaryTextColor : Style.wizardDisabledText
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    indicator: Image {
                        x: serverSelector.width - width - 12
                        y: Math.round((serverSelector.height - height) / 2)
                        width: Style.smallIconSize
                        height: Style.smallIconSize
                        source: "image://svgimage-custom-color/caret-down.svg/" + root.primaryTextColor
                        rotation: serverSelector.popup.visible ? 180 : 0
                        opacity: serverSelector.enabled ? 1 : 0.45
                        fillMode: Image.PreserveAspectFit

                        Behavior on rotation {
                            NumberAnimation {
                                duration: 120
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    background: Rectangle {
                        radius: Style.mediumRoundedButtonRadius
                        color: Style.wizardFieldBackground
                        border.width: Style.normalBorderWidth
                        border.color: serverSelector.activeFocus || serverSelector.popup.visible
                            ? Style.ncBlue
                            : Style.wizardFieldBorder
                    }

                    delegate: BasicControls.ItemDelegate {
                        id: serverDelegate

                        required property int index
                        required property string modelData

                        width: ListView.view ? ListView.view.width : serverSelector.width - 8
                        height: Style.standardPrimaryButtonHeight
                        highlighted: serverSelector.highlightedIndex === index

                        contentItem: Text {
                            text: serverDelegate.modelData
                            font: serverSelector.font
                            color: serverSelector.currentIndex === serverDelegate.index
                                ? Style.wizardSelectedText
                                : root.primaryTextColor
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }

                        background: Rectangle {
                            radius: 6
                            color: {
                                if (serverSelector.currentIndex === serverDelegate.index) {
                                    return Style.ncBlue
                                }
                                if (serverDelegate.highlighted) {
                                    return Style.wizardSecondaryButtonBackground
                                }
                                return Style.wizardFieldBackground
                            }
                        }
                    }

                    popup: BasicControls.Popup {
                        y: serverSelector.height + 4
                        width: serverSelector.width
                        implicitHeight: contentItem.implicitHeight + topPadding + bottomPadding
                        padding: 4

                        contentItem: ListView {
                            clip: true
                            implicitHeight: Math.min(contentHeight, Style.standardPrimaryButtonHeight * 6)
                            model: serverSelector.popup.visible ? serverSelector.delegateModel : null
                            currentIndex: serverSelector.highlightedIndex
                        }

                        background: Rectangle {
                            radius: Style.mediumRoundedButtonRadius
                            color: Style.wizardFieldBackground
                            border.width: Style.normalBorderWidth
                            border.color: Style.wizardSecondaryButtonBorder
                        }
                    }
                }

                WizardButton {
                    primary: true
                    enabled: !root.controller.busy
                    text: qsTr("Log in")
                    textSuffix: "→"
                    Layout.preferredHeight: Style.standardPrimaryButtonHeight
                    Layout.preferredWidth: implicitWidth + 8
                    onClicked: root.controller.submitServerUrl()
                }
            }
            }

            Rectangle {
                x: 8
                y: 0
                width: serverAddressLabel.implicitWidth + 8
                height: serverAddressLabel.implicitHeight
                color: Style.wizardWindowBackground

                EnforcedPlainTextLabel {
                    id: serverAddressLabel
                    anchors.centerIn: parent
                    text: qsTr("Server address")
                    color: root.hintTextColor
                    font.pixelSize: Style.pixelSize
                }
            }
        }

        EnforcedPlainTextLabel {
            visible: root.controller.errorText !== ""
            text: root.controller.errorText
            color: Style.wizardErrorText
            font.pixelSize: Style.pixelSize + 1
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        RowLayout {
            visible: root.controller.busy && root.controller.authStatusText !== ""
            Layout.fillWidth: true
            spacing: 8

            NCBusyIndicator {
                running: root.controller.busy
                visible: running
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
            }

            EnforcedPlainTextLabel {
                text: root.controller.authStatusText
                color: root.hintTextColor
                font.pixelSize: Style.pixelSize + 1
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
