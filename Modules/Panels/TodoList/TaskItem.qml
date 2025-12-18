import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.System
import qs.Widgets

/**
 * Task item row component for the Things 3-style todo list.
 * Shows checkbox, title, project tag, due date, and hover actions.
 */
Rectangle {
  id: root

  required property var taskData
  property bool isCompleted: taskData?.status === "completed"
  property bool showProject: true
  property bool selected: false

  signal clicked()
  signal checkboxClicked()
  signal deleteClicked()

  height: contentRow.implicitHeight + Style.marginM * 2
  color: {
    if (selected) return Color.mPrimaryContainer;
    if (mouseArea.containsMouse) return Color.mHover;
    return Color.transparent;
  }
  radius: Style.radiusS

  Behavior on color {
    ColorAnimation { duration: Style.animationFast }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onClicked: mouse => {
      if (mouse.button === Qt.LeftButton) {
        root.clicked();
      }
    }
  }

  RowLayout {
    id: contentRow
    anchors.fill: parent
    anchors.margins: Style.marginM
    spacing: Style.marginS

    // Checkbox
    Rectangle {
      id: checkbox
      width: Math.round(20 * Style.uiScaleRatio)
      height: width
      radius: width / 2
      color: isCompleted ? Color.mPrimary : (checkboxArea.containsMouse ? Color.mPrimaryContainer : Color.transparent)
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

    // Task content
    ColumnLayout {
      Layout.fillWidth: true
      spacing: 2

      // Title row
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NText {
          text: taskData?.description ?? ""
          pointSize: Style.fontSizeS
          color: isCompleted ? Color.mOnSurfaceVariant : Color.mOnSurface
          font.strikeout: isCompleted
          wrapMode: Text.WordWrap
          Layout.fillWidth: true
          opacity: isCompleted ? 0.7 : 1.0
        }
      }

      // Metadata row (project, tags, date)
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginXS
        visible: hasMetadata

        property bool hasMetadata: (showProject && taskData?.project) || (taskData?.tags && taskData.tags.length > 0) || taskData?.due || taskData?.scheduled

        // Project badge
        Rectangle {
          visible: showProject && taskData?.project
          height: projectLabel.implicitHeight + 4
          width: projectLabel.implicitWidth + Style.marginS * 2
          radius: Style.radiusXS
          color: Color.mSecondaryContainer

          NText {
            id: projectLabel
            anchors.centerIn: parent
            text: taskData?.project ?? ""
            pointSize: Style.fontSizeXS
            color: Color.mOnSecondaryContainer
          }
        }

        // Tags
        Repeater {
          model: {
            var tags = taskData?.tags ?? [];
            return tags.filter(t => t !== "someday").slice(0, 3);
          }
          delegate: Rectangle {
            height: tagLabel.implicitHeight + 4
            width: tagLabel.implicitWidth + Style.marginS * 2
            radius: Style.radiusXS
            color: Color.mTertiaryContainer

            NText {
              id: tagLabel
              anchors.centerIn: parent
              text: modelData
              pointSize: Style.fontSizeXS
              color: Color.mOnTertiaryContainer
            }
          }
        }

        Item { Layout.fillWidth: true }

        // Due date
        NText {
          visible: !!taskData?.due || !!taskData?.scheduled
          text: _formatDate(taskData?.due ?? taskData?.scheduled)
          pointSize: Style.fontSizeXS
          color: _isOverdue(taskData?.due) ? Color.mError : Color.mOnSurfaceVariant
        }
      }
    }

    // Delete button (shown on hover)
    NIconButton {
      icon: "trash"
      baseSize: 24
      visible: mouseArea.containsMouse && !isCompleted
      opacity: visible ? 1.0 : 0.0
      onClicked: root.deleteClicked()

      Behavior on opacity {
        NumberAnimation { duration: Style.animationFast }
      }
    }
  }

  // Helper to format date from TaskWarrior format (YYYYMMDDTHHMMSSZ)
  function _formatDate(dateStr) {
    if (!dateStr) return "";

    try {
      var year = parseInt(dateStr.substring(0, 4));
      var month = parseInt(dateStr.substring(4, 6)) - 1;
      var day = parseInt(dateStr.substring(6, 8));
      var taskDate = new Date(year, month, day);
      var today = new Date();
      today.setHours(0, 0, 0, 0);

      var tomorrow = new Date(today);
      tomorrow.setDate(tomorrow.getDate() + 1);

      var nextWeek = new Date(today);
      nextWeek.setDate(nextWeek.getDate() + 7);

      if (taskDate.toDateString() === today.toDateString()) {
        return I18n.tr("todolist.date.today");
      } else if (taskDate.toDateString() === tomorrow.toDateString()) {
        return I18n.tr("todolist.date.tomorrow");
      } else if (taskDate < today) {
        var daysAgo = Math.floor((today - taskDate) / (1000 * 60 * 60 * 24));
        return I18n.tr("todolist.date.overdue", {"days": daysAgo});
      } else if (taskDate < nextWeek) {
        var dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
        return dayNames[taskDate.getDay()];
      } else {
        return taskDate.toLocaleDateString(undefined, { month: "short", day: "numeric" });
      }
    } catch (e) {
      return dateStr;
    }
  }

  function _isOverdue(dateStr) {
    if (!dateStr) return false;
    try {
      var year = parseInt(dateStr.substring(0, 4));
      var month = parseInt(dateStr.substring(4, 6)) - 1;
      var day = parseInt(dateStr.substring(6, 8));
      var taskDate = new Date(year, month, day);
      var today = new Date();
      today.setHours(0, 0, 0, 0);
      return taskDate < today;
    } catch (e) {
      return false;
    }
  }
}
