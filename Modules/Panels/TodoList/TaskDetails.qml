import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.System
import qs.Widgets

/**
 * Task detail editor panel for the Things 3-style todo list.
 * Shows editable fields for task properties.
 */
Rectangle {
    id: root

    property var taskData: null
    property bool isVisible: taskData !== null
    property string _lastSavedDescription: ""

    signal closeRequested
    signal taskModified

    color: Color.mSurface
    border.color: Color.mOutline
    border.width: Style.borderS
    radius: Style.radiusM

    Timer {
        id: _autosaveDescriptionTimer
        interval: 450
        repeat: false
        onTriggered: {
            if (!root.taskData)
                return;
            var next = titleInput.text.trim();
            if (!next)
                return;
            if (next === root._lastSavedDescription)
                return;
            TaskService.modifyTask(root.taskData.id.toString(), {
                description: next
            });
            root._lastSavedDescription = next;
        }
    }

    function _syncTitleFromTaskData() {
        var current = (taskData && taskData.description !== undefined && taskData.description !== null) ? String(taskData.description) : "";
        root._lastSavedDescription = current.trim();
        if (!titleInput.activeFocus) {
            titleInput.text = current;
        }
    }

    onTaskDataChanged: _syncTitleFromTaskData()

    // Close button
    NIconButton {
        id: closeButton
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.marginS
        icon: "close"
        baseSize: 28
        onClicked: closeRequested()
        z: 10
    }

    NScrollView {
        anchors.fill: parent
        anchors.margins: Style.marginM
        anchors.topMargin: Style.marginL + closeButton.height
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: parent.width
            spacing: Style.marginXL

            // Task title (editable)
            Rectangle {
                Layout.fillWidth: true
                height: Math.max(titleInput.implicitHeight + Style.marginXL * 2, Math.round(72 * Style.uiScaleRatio))
                color: Color.mSurfaceVariant
                radius: Style.radiusS
                border.color: titleInput.activeFocus ? Color.mPrimary : Color.transparent

                TextInput {
                    id: titleInput
                    anchors.fill: parent
                    anchors.margins: Style.marginXL
                    text: (taskData && taskData.description !== undefined && taskData.description !== null) ? String(taskData.description) : ""
                    color: Color.mOnSurface
                    font.family: Settings.data.ui.fontDefault
                    font.pixelSize: Style.fontSizeL * Style.uiScaleRatio
                    font.weight: Font.DemiBold
                    wrapMode: Text.WordWrap
                    selectByMouse: true

                    onTextChanged: {
                        if (!root.taskData)
                            return;
                        _autosaveDescriptionTimer.restart();
                    }

                    onEditingFinished: {
                        // Fallback: ensure we don't lose edits when focus changes quickly.
                        _autosaveDescriptionTimer.restart();
                    }
                }
            }

            // Notes section
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginXS

                NText {
                    text: I18n.tr("todolist.details.notes")
                    pointSize: Style.fontSizeXS
                    color: Color.mOnSurfaceVariant
                    font.weight: Font.Medium
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: Math.max(notesInput.implicitHeight + Style.marginM * 2, Math.round(220 * Style.uiScaleRatio))
                    color: Color.mSurfaceVariant
                    radius: Style.radiusS
                    border.color: notesInput.activeFocus ? Color.mPrimary : Color.transparent

                    TextArea {
                        id: notesInput
                        anchors.fill: parent
                        anchors.margins: Style.marginM
                        text: _getAnnotations()
                        color: Color.mOnSurface
                        font.family: Settings.data.ui.fontDefault
                        font.pixelSize: Style.fontSizeM * Style.uiScaleRatio
                        wrapMode: Text.WordWrap
                        placeholderText: I18n.tr("todolist.details.notes-placeholder")
                        placeholderTextColor: Color.mOnSurfaceVariant

                        background: Item {}
                    }
                }

                // Add note button
                NButton {
                    text: I18n.tr("todolist.details.add-note")
                    icon: "plus"
                    visible: notesInput.text.trim() && notesInput.text !== _getAnnotations()
                    onClicked: {
                        TaskService.addAnnotation(taskData.id.toString(), notesInput.text.trim());
                    }
                }
            }

            // When (scheduled date)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginXS

                NText {
                    text: I18n.tr("todolist.details.when")
                    pointSize: Style.fontSizeXS
                    color: Color.mOnSurfaceVariant
                    font.weight: Font.Medium
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.marginS

                    Repeater {
                        model: [
                            {
                                label: I18n.tr("todolist.date.today"),
                                value: "today"
                            },
                            {
                                label: I18n.tr("todolist.date.tomorrow"),
                                value: "tomorrow"
                            },
                            {
                                label: I18n.tr("todolist.details.next-week"),
                                value: "monday"
                            },
                            {
                                label: I18n.tr("todolist.details.someday"),
                                value: "someday"
                            }
                        ]
                        delegate: Rectangle {
                            width: dateChipLabel.implicitWidth + Style.marginM * 2
                            height: dateChipLabel.implicitHeight + Style.marginS * 2
                            radius: Style.radiusS
                            color: _isDateSelected(modelData.value) ? Qt.alpha(Color.mPrimary, 0.18) : (dateChipArea.containsMouse ? Color.mHover : Color.mSurfaceVariant)
                            border.color: _isDateSelected(modelData.value) ? Color.mPrimary : Color.transparent

                            NText {
                                id: dateChipLabel
                                anchors.centerIn: parent
                                text: modelData.label
                                pointSize: Style.fontSizeXS
                                color: Color.mOnSurface
                            }

                            MouseArea {
                                id: dateChipArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: _setScheduledDate(modelData.value)
                            }
                        }
                    }
                }
            }

            // Due date
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginXS

                NText {
                    text: I18n.tr("todolist.details.deadline")
                    pointSize: Style.fontSizeXS
                    color: Color.mOnSurfaceVariant
                    font.weight: Font.Medium
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: dueDateInput.implicitHeight + Style.marginS * 2
                    color: Color.mSurfaceVariant
                    radius: Style.radiusS
                    border.color: dueDateInput.activeFocus ? Color.mPrimary : Color.transparent

                    TextInput {
                        id: dueDateInput
                        anchors.fill: parent
                        anchors.margins: Style.marginS
                        text: _formatDateForEdit(taskData ? taskData.due : null)
                        color: Color.mOnSurface
                        font.family: Settings.data.ui.fontDefault
                        font.pixelSize: Style.fontSizeS * Style.uiScaleRatio
                        selectByMouse: true

                        property string placeholderText: I18n.tr("todolist.details.deadline-placeholder")

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: dueDateInput.placeholderText
                            color: Color.mOnSurfaceVariant
                            font: dueDateInput.font
                            visible: !dueDateInput.text && !dueDateInput.activeFocus
                        }

                        onEditingFinished: {
                            if (text.trim()) {
                                TaskService.modifyTask(taskData.id.toString(), {
                                    due: text.trim()
                                });
                            } else {
                                TaskService.modifyTask(taskData.id.toString(), {
                                    due: null
                                });
                            }
                        }
                    }
                }
            }

            // Tags
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginXS

                NText {
                    text: I18n.tr("todolist.details.tags")
                    pointSize: Style.fontSizeXS
                    color: Color.mOnSurfaceVariant
                    font.weight: Font.Medium
                }

                // Current tags
                Flow {
                    Layout.fillWidth: true
                    spacing: Style.marginXS
                    visible: !!(taskData && taskData.tags && taskData.tags.length > 0)

                    Repeater {
                        model: (taskData && taskData.tags) ? taskData.tags : []
                        delegate: Rectangle {
                            width: tagContent.implicitWidth + Style.marginS * 2
                            height: tagContent.implicitHeight + 4
                            radius: Style.radiusXS
                            color: Qt.alpha(Color.mTertiary, 0.18)

                            RowLayout {
                                id: tagContent
                                anchors.centerIn: parent
                                spacing: 4

                                NText {
                                    text: modelData
                                    pointSize: Style.fontSizeXS
                                    color: Color.mOnSurface
                                }

                                NIcon {
                                    icon: "close"
                                    pointSize: Style.fontSizeXS
                                    color: Color.mOnSurface
                                    visible: removeTagArea.containsMouse

                                    MouseArea {
                                        id: removeTagArea
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: _removeTag(modelData)
                                    }
                                }
                            }
                        }
                    }
                }

                // Add tag input
                Rectangle {
                    Layout.fillWidth: true
                    height: tagInput.implicitHeight + Style.marginS * 2
                    color: Color.mSurfaceVariant
                    radius: Style.radiusS
                    border.color: tagInput.activeFocus ? Color.mPrimary : Color.transparent

                    TextInput {
                        id: tagInput
                        anchors.fill: parent
                        anchors.margins: Style.marginS
                        color: Color.mOnSurface
                        font.family: Settings.data.ui.fontDefault
                        font.pixelSize: Style.fontSizeS * Style.uiScaleRatio
                        selectByMouse: true

                        property string placeholderText: I18n.tr("todolist.details.add-tag")

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: tagInput.placeholderText
                            color: Color.mOnSurfaceVariant
                            font: tagInput.font
                            visible: !tagInput.text && !tagInput.activeFocus
                        }

                        onAccepted: {
                            if (text.trim()) {
                                _addTag(text.trim());
                                text = "";
                            }
                        }
                    }
                }
            }

            // Action buttons
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Style.marginL
                spacing: Style.marginS

                NIconButton {
                    icon: "check"
                    tooltipText: I18n.tr("todolist.details.complete")
                    baseSize: 24
                    density: "compact"
                    customRadius: Style.radiusS
                    colorBg: Color.mPrimary
                    colorFg: Color.mOnPrimary
                    colorBgHover: Qt.alpha(Color.mPrimary, 0.85)
                    colorFgHover: Color.mOnPrimary
                    colorBorder: Qt.alpha(Color.mPrimary, 0.2)
                    colorBorderHover: Qt.alpha(Color.mPrimary, 0.2)
                    visible: !!(taskData && taskData.status !== "completed")
                    onClicked: {
                        TaskService.completeTask(taskData.id.toString());
                        closeRequested();
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                NIconButton {
                    icon: "trash"
                    tooltipText: I18n.tr("todolist.details.delete")
                    baseSize: 24
                    density: "compact"
                    customRadius: Style.radiusS
                    colorBg: Color.mError
                    colorFg: Color.mOnError
                    colorBgHover: Qt.alpha(Color.mError, 0.85)
                    colorFgHover: Color.mOnError
                    colorBorder: Qt.alpha(Color.mError, 0.2)
                    colorBorderHover: Qt.alpha(Color.mError, 0.2)
                    onClicked: {
                        TaskService.deleteTask(taskData.id.toString());
                        closeRequested();
                    }
                }
            }
        }
    }

    // Helper functions
    function _getAnnotations() {
        if (!taskData || !taskData.annotations)
            return "";
        var out = [];
        for (var i = 0; i < taskData.annotations.length; i++) {
            var ann = taskData.annotations[i];
            if (!ann)
                continue;
            if (ann.description === undefined || ann.description === null)
                continue;
            out.push(String(ann.description));
        }
        return out.join("\n");
    }

    function _formatDateForEdit(dateStr) {
        if (!dateStr)
            return "";
        try {
            var year = dateStr.substring(0, 4);
            var month = dateStr.substring(4, 6);
            var day = dateStr.substring(6, 8);
            return year + "-" + month + "-" + day;
        } catch (e) {
            return dateStr;
        }
    }

    function _isDateSelected(value) {
        if (value === "someday") {
            return !!(taskData && taskData.tags && taskData.tags.indexOf("someday") !== -1);
        }
        // Check scheduled date
        var scheduled = taskData ? taskData.scheduled : null;
        if (!scheduled)
            return false;

        var today = new Date();
        today.setHours(0, 0, 0, 0);

        var taskDate = new Date(parseInt(scheduled.substring(0, 4)), parseInt(scheduled.substring(4, 6)) - 1, parseInt(scheduled.substring(6, 8)));

        if (value === "today")
            return taskDate.toDateString() === today.toDateString();

        var tomorrow = new Date(today);
        tomorrow.setDate(tomorrow.getDate() + 1);
        if (value === "tomorrow")
            return taskDate.toDateString() === tomorrow.toDateString();

        return false;
    }

    function _setScheduledDate(value) {
        if (value === "someday") {
            _addTag("someday");
            TaskService.modifyTask(taskData.id.toString(), {
                scheduled: null
            });
        } else {
            _removeTag("someday");
            TaskService.modifyTask(taskData.id.toString(), {
                scheduled: value
            });
        }
    }

    function _addTag(tag) {
        if (!taskData)
            return;
        var currentTags = (taskData.tags && taskData.tags.length) ? taskData.tags : [];
        if (currentTags.indexOf(tag) === -1) {
            TaskService.modifyTask(taskData.id.toString(), {
                "+": tag
            });
        }
    }

    function _removeTag(tag) {
        TaskService.modifyTask(taskData.id.toString(), {
            "-": tag
        });
    }
}
