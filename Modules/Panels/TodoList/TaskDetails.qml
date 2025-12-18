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

  signal closeRequested()
  signal taskModified()

  color: Color.mSurface
  border.color: Color.mOutlineVariant
  border.width: Style.borderS
  radius: Style.radiusM

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
      spacing: Style.marginL

      // Task title (editable)
      Rectangle {
        Layout.fillWidth: true
        height: titleInput.implicitHeight + Style.marginM * 2
        color: Color.mSurfaceVariant
        radius: Style.radiusS
        border.color: titleInput.activeFocus ? Color.mPrimary : Color.transparent

        TextInput {
          id: titleInput
          anchors.fill: parent
          anchors.margins: Style.marginM
          text: taskData?.description ?? ""
          color: Color.mOnSurface
          font.family: Settings.data.ui.fontDefault
          font.pixelSize: Style.fontSizeM * Style.uiScaleRatio
          font.weight: Font.DemiBold
          wrapMode: Text.WordWrap
          selectByMouse: true

          onEditingFinished: {
            if (text !== taskData?.description && text.trim()) {
              TaskService.modifyTask(taskData.id.toString(), { description: text.trim() });
            }
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
          height: Math.max(notesInput.implicitHeight + Style.marginM * 2, 80)
          color: Color.mSurfaceVariant
          radius: Style.radiusS
          border.color: notesInput.activeFocus ? Color.mPrimary : Color.transparent

          TextArea {
            id: notesInput
            anchors.fill: parent
            anchors.margins: Style.marginS
            text: _getAnnotations()
            color: Color.mOnSurface
            font.family: Settings.data.ui.fontDefault
            font.pixelSize: Style.fontSizeS * Style.uiScaleRatio
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
              { label: I18n.tr("todolist.date.today"), value: "today" },
              { label: I18n.tr("todolist.date.tomorrow"), value: "tomorrow" },
              { label: I18n.tr("todolist.details.next-week"), value: "monday" },
              { label: I18n.tr("todolist.details.someday"), value: "someday" }
            ]
            delegate: Rectangle {
              width: dateChipLabel.implicitWidth + Style.marginM * 2
              height: dateChipLabel.implicitHeight + Style.marginS * 2
              radius: Style.radiusS
              color: _isDateSelected(modelData.value) ? Color.mPrimaryContainer : (dateChipArea.containsMouse ? Color.mHover : Color.mSurfaceVariant)
              border.color: _isDateSelected(modelData.value) ? Color.mPrimary : Color.transparent

              NText {
                id: dateChipLabel
                anchors.centerIn: parent
                text: modelData.label
                pointSize: Style.fontSizeXS
                color: _isDateSelected(modelData.value) ? Color.mOnPrimaryContainer : Color.mOnSurface
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
            text: _formatDateForEdit(taskData?.due)
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
                TaskService.modifyTask(taskData.id.toString(), { due: text.trim() });
              } else {
                TaskService.modifyTask(taskData.id.toString(), { due: null });
              }
            }
          }
        }
      }

      // Project
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginXS

        NText {
          text: I18n.tr("todolist.details.project")
          pointSize: Style.fontSizeXS
          color: Color.mOnSurfaceVariant
          font.weight: Font.Medium
        }

        Rectangle {
          Layout.fillWidth: true
          height: projectInput.implicitHeight + Style.marginS * 2
          color: Color.mSurfaceVariant
          radius: Style.radiusS
          border.color: projectInput.activeFocus ? Color.mPrimary : Color.transparent

          TextInput {
            id: projectInput
            anchors.fill: parent
            anchors.margins: Style.marginS
            text: taskData?.project ?? ""
            color: Color.mOnSurface
            font.family: Settings.data.ui.fontDefault
            font.pixelSize: Style.fontSizeS * Style.uiScaleRatio
            selectByMouse: true

            property string placeholderText: I18n.tr("todolist.details.project-placeholder")

            Text {
              anchors.fill: parent
              verticalAlignment: Text.AlignVCenter
              text: projectInput.placeholderText
              color: Color.mOnSurfaceVariant
              font: projectInput.font
              visible: !projectInput.text && !projectInput.activeFocus
            }

            onEditingFinished: {
              if (text.trim() !== (taskData?.project ?? "")) {
                TaskService.modifyTask(taskData.id.toString(), { project: text.trim() || null });
              }
            }
          }
        }

        // Existing projects as chips
        Flow {
          Layout.fillWidth: true
          spacing: Style.marginXS
          visible: TaskService.projects.length > 0

          Repeater {
            model: TaskService.projects.slice(0, 5)
            delegate: Rectangle {
              width: projectChipLabel.implicitWidth + Style.marginS * 2
              height: projectChipLabel.implicitHeight + 4
              radius: Style.radiusXS
              color: taskData?.project === modelData ? Color.mPrimaryContainer : (projectChipArea.containsMouse ? Color.mHover : Color.mSurfaceVariant)

              NText {
                id: projectChipLabel
                anchors.centerIn: parent
                text: modelData
                pointSize: Style.fontSizeXS
                color: taskData?.project === modelData ? Color.mOnPrimaryContainer : Color.mOnSurface
              }

              MouseArea {
                id: projectChipArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (taskData?.project === modelData) {
                    TaskService.modifyTask(taskData.id.toString(), { project: null });
                  } else {
                    TaskService.modifyTask(taskData.id.toString(), { project: modelData });
                  }
                  projectInput.text = taskData?.project === modelData ? "" : modelData;
                }
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
          visible: taskData?.tags && taskData.tags.length > 0

          Repeater {
            model: taskData?.tags ?? []
            delegate: Rectangle {
              width: tagContent.implicitWidth + Style.marginS * 2
              height: tagContent.implicitHeight + 4
              radius: Style.radiusXS
              color: Color.mTertiaryContainer

              RowLayout {
                id: tagContent
                anchors.centerIn: parent
                spacing: 4

                NText {
                  text: modelData
                  pointSize: Style.fontSizeXS
                  color: Color.mOnTertiaryContainer
                }

                NIcon {
                  icon: "close"
                  pointSize: Style.fontSizeXS
                  color: Color.mOnTertiaryContainer
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
        spacing: Style.marginM

        NButton {
          text: I18n.tr("todolist.details.complete")
          icon: "check"
          backgroundColor: Color.mPrimary
          textColor: Color.mOnPrimary
          visible: taskData?.status !== "completed"
          onClicked: {
            TaskService.completeTask(taskData.id.toString());
            closeRequested();
          }
        }

        Item { Layout.fillWidth: true }

        NButton {
          text: I18n.tr("todolist.details.delete")
          icon: "trash"
          backgroundColor: Color.mError
          textColor: Color.mOnError
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
    if (!taskData?.annotations) return "";
    return taskData.annotations.map(a => a.description).join("\n");
  }

  function _formatDateForEdit(dateStr) {
    if (!dateStr) return "";
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
      return taskData?.tags && taskData.tags.includes("someday");
    }
    // Check scheduled date
    var scheduled = taskData?.scheduled;
    if (!scheduled) return false;

    var today = new Date();
    today.setHours(0, 0, 0, 0);

    var taskDate = new Date(
      parseInt(scheduled.substring(0, 4)),
      parseInt(scheduled.substring(4, 6)) - 1,
      parseInt(scheduled.substring(6, 8))
    );

    if (value === "today") return taskDate.toDateString() === today.toDateString();

    var tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);
    if (value === "tomorrow") return taskDate.toDateString() === tomorrow.toDateString();

    return false;
  }

  function _setScheduledDate(value) {
    if (value === "someday") {
      _addTag("someday");
      TaskService.modifyTask(taskData.id.toString(), { scheduled: null });
    } else {
      _removeTag("someday");
      TaskService.modifyTask(taskData.id.toString(), { scheduled: value });
    }
  }

  function _addTag(tag) {
    var currentTags = taskData?.tags ?? [];
    if (!currentTags.includes(tag)) {
      TaskService.modifyTask(taskData.id.toString(), { "+": tag });
    }
  }

  function _removeTag(tag) {
    TaskService.modifyTask(taskData.id.toString(), { "-": tag });
  }
}
