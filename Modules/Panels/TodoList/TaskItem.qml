import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.System
import qs.Widgets

/**
 * Task item row component for the Things 3-style todo list.
 * Shows checkbox, title, tags, due date, and hover actions.
 */
Rectangle {
    id: root

    required property var taskData
    property bool isCompleted: !!(taskData && taskData.status === "completed")
    property bool selected: false
    readonly property int _checkboxSize: Math.round(20 * Style.uiScaleRatio)

    signal clicked
    signal checkboxClicked
    signal deleteClicked

    HoverHandler {
        id: hoverHandler
    }

    height: contentRow.implicitHeight + Style.marginM * 2
    color: {
        if (selected)
            return Qt.alpha(Color.mPrimary, 0.18);
        if (hoverHandler.hovered)
            return Color.mHover;
        return Color.transparent;
    }
    radius: Style.radiusS

    Behavior on color {
        ColorAnimation {
            duration: Style.animationFast
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: function (mouse) {
            if (mouse.button === Qt.LeftButton) {
                root.clicked();
            }
        }
    }

    // Checkbox (overlay) - align with the title line, not the full row height.
    Rectangle {
        id: checkbox
        width: root._checkboxSize
        height: width
        anchors.left: parent.left
        anchors.leftMargin: Style.marginM
        anchors.verticalCenter: parent.verticalCenter
        radius: width / 2
        color: isCompleted ? Color.mPrimary : (checkboxArea.containsMouse ? Qt.alpha(Color.mPrimary, 0.18) : Color.transparent)
        border.color: isCompleted ? Color.mPrimary : (checkboxArea.containsMouse ? Color.mPrimary : Color.mOutline)
        border.width: Style.borderS

        NIcon {
            anchors.centerIn: parent
            icon: "check"
            pointSize: Style.fontSizeXS
            color: isCompleted ? Color.mOnPrimary : Color.mPrimary
            visible: isCompleted || checkboxArea.containsMouse
        }

        MouseArea {
            id: checkboxArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.checkboxClicked()
        }
    }

    RowLayout {
        id: contentRow
        anchors.fill: parent
        anchors.leftMargin: Style.marginM + root._checkboxSize + Style.marginS
        anchors.topMargin: Style.marginM
        anchors.bottomMargin: Style.marginM
        anchors.rightMargin: Style.marginM + deleteButton.baseSize + Style.marginS
        spacing: Style.marginS

        // Task content
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            // Title row
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NText {
                    id: titleLabel
                    text: (taskData && taskData.description !== undefined && taskData.description !== null) ? String(taskData.description) : ""
                    pointSize: Style.fontSizeL
                    color: isCompleted ? Color.mOnSurfaceVariant : Color.mOnSurface
                    font.strikeout: isCompleted
                    wrapMode: Text.NoWrap
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    opacity: isCompleted ? 0.7 : 1.0
                }

                // Due / scheduled date (kept on the same line as the title)
                NText {
                    visible: !!(taskData && (taskData.due || taskData.scheduled))
                    text: _formatDate((taskData && taskData.due) ? taskData.due : (taskData ? taskData.scheduled : null))
                    pointSize: Style.fontSizeXS
                    color: _isOverdue(taskData ? taskData.due : null) ? Color.mError : Color.mOnSurfaceVariant
                    wrapMode: Text.NoWrap
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            // Metadata row (tags)
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginXS
                visible: hasMetadata

                property bool hasMetadata: !!(taskData && taskData.tags && taskData.tags.length > 0)

                // Tags
                Repeater {
                    model: _getVisibleTags()
                    delegate: Rectangle {
                        height: tagLabel.implicitHeight + 4
                        width: tagLabel.implicitWidth + Style.marginS * 2
                        radius: Style.radiusXS
                        color: Qt.alpha(Color.mTertiary, 0.18)

                        NText {
                            id: tagLabel
                            anchors.centerIn: parent
                            text: modelData
                            pointSize: Style.fontSizeXS
                            color: Color.mOnSurface
                        }
                    }
                }
            }
        }
    }

    // Delete button (shown on hover) - overlay so it doesn't reflow the RowLayout.
    NDestructiveIconButton {
        id: deleteButton
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: Style.marginM
        enabled: hoverHandler.hovered && !isCompleted
        opacity: enabled ? 1.0 : 0.0
        onClicked: root.deleteClicked()

        Behavior on opacity {
            NumberAnimation {
                duration: Style.animationFast
            }
        }
    }

    // Helper to format date from TaskWarrior format (YYYYMMDDTHHMMSSZ)
    function _formatDate(dateStr) {
        if (!dateStr)
            return "";

        try {
            var taskDate = TaskwarriorDate.parse(dateStr);
            if (!taskDate)
                return "";

            var taskDay = TaskwarriorDate.startOfLocalDay(taskDate);

            var today = new Date();
            today.setHours(0, 0, 0, 0);

            var tomorrow = new Date(today);
            tomorrow.setDate(tomorrow.getDate() + 1);

            var nextWeek = new Date(today);
            nextWeek.setDate(nextWeek.getDate() + 7);

            if (taskDay.toDateString() === today.toDateString()) {
                return I18n.tr("todolist.date.today");
            } else if (taskDay.toDateString() === tomorrow.toDateString()) {
                return I18n.tr("todolist.date.tomorrow");
            } else if (taskDay < today) {
                var daysAgo = Math.floor((today - taskDay) / (1000 * 60 * 60 * 24));
                return I18n.tr("todolist.date.overdue", {
                    "days": daysAgo
                });
            } else if (taskDay < nextWeek) {
                var dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
                return dayNames[taskDay.getDay()];
            } else {
                return taskDay.toLocaleDateString(undefined, {
                    month: "short",
                    day: "numeric"
                });
            }
        } catch (e) {
            return dateStr;
        }
    }

    function _getVisibleTags() {
        var tags = (taskData && taskData.tags) ? taskData.tags : [];
        var visible = [];
        for (var i = 0; i < tags.length; i++) {
            var tag = tags[i];
            if (!tag)
                continue;
            if (tag === "someday")
                continue;
            visible.push(tag);
            if (visible.length >= 3)
                break;
        }
        return visible;
    }

    function _isOverdue(dateStr) {
        if (!dateStr)
            return false;
        try {
            var taskDate = TaskwarriorDate.parse(dateStr);
            if (!taskDate)
                return false;
            var taskDay = TaskwarriorDate.startOfLocalDay(taskDate);
            var today = new Date();
            today.setHours(0, 0, 0, 0);
            return taskDay < today;
        } catch (e) {
            return false;
        }
    }
}
