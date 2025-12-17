import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.MainScreen
import qs.Services.System
import qs.Services.UI
import qs.Widgets

SmartPanel {
  id: root

  preferredWidth: Math.round(400 * Style.uiScaleRatio)

  panelContent: Item {
    anchors.fill: parent

    // SmartPanel uses this to calculate panel height dynamically
    readonly property real contentPreferredHeight: content.implicitHeight + (Style.marginL * 2)

    ColumnLayout {
      id: content
      x: Style.marginL
      y: Style.marginL
      width: parent.width - (Style.marginL * 2)
      spacing: Style.marginM

      // Header
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NIcon {
          icon: "checklist"
          pointSize: Style.fontSizeXL
          color: Color.mPrimary
        }

        NText {
          text: I18n.tr("todolist.panel.title")
          pointSize: Style.fontSizeL
          font.weight: Style.fontWeightBold
          color: Color.mOnSurface
          Layout.fillWidth: true
        }

        // Refresh button
        NIconButton {
          icon: "refresh"
          baseSize: 28
          onClicked: TaskService.loadTasks()
          tooltipText: I18n.tr("todolist.panel.refresh")
        }
      }

      // Add task input
      Rectangle {
        Layout.fillWidth: true
        height: Math.round(44 * Style.uiScaleRatio)
        color: Color.mSurfaceVariant
        radius: Style.radiusS
        border.color: addInput.activeFocus ? Color.mPrimary : Color.mOutline
        border.width: Style.borderS

        RowLayout {
          anchors.fill: parent
          anchors.margins: Style.marginS
          spacing: Style.marginS

          NIcon {
            icon: "plus"
            pointSize: Style.fontSizeM
            color: Color.mOnSurfaceVariant
          }

          TextInput {
            id: addInput
            Layout.fillWidth: true
            Layout.fillHeight: true
            verticalAlignment: Text.AlignVCenter
            color: Color.mOnSurface
            font.family: Settings.data.ui.fontDefault
            font.pixelSize: Style.fontSizeS * Style.uiScaleRatio
            clip: true
            selectByMouse: true

            property string placeholderText: I18n.tr("todolist.panel.placeholder")

            Text {
              anchors.fill: parent
              verticalAlignment: Text.AlignVCenter
              text: addInput.placeholderText
              color: Color.mOnSurfaceVariant
              font: addInput.font
              visible: !addInput.text && !addInput.activeFocus
            }

            onAccepted: {
              if (text.trim()) {
                TaskService.addTask(text.trim());
                text = "";
              }
            }

            Keys.onEscapePressed: {
              text = "";
              focus = false;
            }
          }

          NIconButton {
            icon: "arrow-right"
            baseSize: 28
            enabled: addInput.text.trim().length > 0
            opacity: enabled ? 1.0 : 0.5
            onClicked: {
              if (addInput.text.trim()) {
                TaskService.addTask(addInput.text.trim());
                addInput.text = "";
              }
            }
          }
        }
      }

      // Task count
      NText {
        visible: TaskService.pendingCount > 0
        text: I18n.tr("todolist.panel.count", {"count": TaskService.pendingCount})
        pointSize: Style.fontSizeXS
        color: Color.mOnSurfaceVariant
      }

      // Task list or empty state
      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(200, taskList.implicitHeight)

        // Task list
        Column {
          id: taskList
          width: parent.width
          spacing: Style.marginS
          visible: TaskService.tasks.length > 0

          Repeater {
            model: TaskService.tasks

            delegate: Rectangle {
              id: taskItem
              width: taskList.width
              height: taskRow.implicitHeight + Style.marginM * 2
              color: taskMouseArea.containsMouse ? Color.mHover : Color.mSurfaceVariant
              radius: Style.radiusS

              property var taskData: modelData

              Behavior on color {
                ColorAnimation { duration: Style.animationFast }
              }

              MouseArea {
                id: taskMouseArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                onClicked: mouse => {
                  if (mouse.button === Qt.RightButton) {
                    taskContextMenu.taskId = taskData.id.toString();
                    taskContextMenu.popup();
                  }
                }
              }

              RowLayout {
                id: taskRow
                anchors.fill: parent
                anchors.margins: Style.marginM
                spacing: Style.marginS

                // Checkbox to complete
                Rectangle {
                  width: Math.round(22 * Style.uiScaleRatio)
                  height: width
                  radius: Style.radiusXS
                  color: checkboxArea.containsMouse ? Color.mPrimary : Color.transparent
                  border.color: checkboxArea.containsMouse ? Color.mPrimary : Color.mOutline
                  border.width: Style.borderS

                  NIcon {
                    anchors.centerIn: parent
                    icon: "check"
                    pointSize: Style.fontSizeS
                    color: Color.mOnPrimary
                    visible: checkboxArea.containsMouse
                  }

                  MouseArea {
                    id: checkboxArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      TaskService.completeTask(taskData.id.toString());
                    }
                  }
                }

                // Task description
                NText {
                  text: taskData.description || ""
                  pointSize: Style.fontSizeS
                  color: Color.mOnSurface
                  wrapMode: Text.WordWrap
                  Layout.fillWidth: true
                }

                // Delete button
                NIconButton {
                  icon: "trash"
                  baseSize: 24
                  visible: taskMouseArea.containsMouse
                  onClicked: {
                    TaskService.deleteTask(taskData.id.toString());
                  }
                }
              }
            }
          }
        }

        // Empty state
        Column {
          anchors.centerIn: parent
          spacing: Style.marginM
          visible: TaskService.tasks.length === 0 && !TaskService.loading

          NIcon {
            icon: "checklist"
            pointSize: Style.fontSizeXXL
            color: Color.mOnSurfaceVariant
            opacity: 0.5
            anchors.horizontalCenter: parent.horizontalCenter
          }

          NText {
            text: TaskService.isAvailable
              ? I18n.tr("todolist.panel.empty")
              : I18n.tr("todolist.panel.not-available")
            pointSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
          }

          NText {
            visible: !TaskService.isAvailable
            text: I18n.tr("todolist.panel.install-hint")
            pointSize: Style.fontSizeXS
            color: Color.mOnSurfaceVariant
            opacity: 0.7
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
          }
        }

        // Loading indicator
        NText {
          anchors.centerIn: parent
          visible: TaskService.loading
          text: I18n.tr("todolist.panel.loading")
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
        }
      }
    }

    // Context menu for tasks
    Menu {
      id: taskContextMenu
      property string taskId: ""

      background: Rectangle {
        implicitWidth: 160
        color: Color.mSurface
        radius: Style.radiusS
        border.color: Color.mOutline
        border.width: Style.borderS
      }

      MenuItem {
        id: completeMenuItem
        text: I18n.tr("todolist.panel.complete")

        background: Rectangle {
          color: completeMenuArea.containsMouse ? Color.mHover : Color.transparent
          radius: Style.radiusXS
        }

        contentItem: RowLayout {
          spacing: Style.marginS
          NIcon {
            icon: "check"
            pointSize: Style.fontSizeM
            color: completeMenuArea.containsMouse ? Color.mOnHover : Color.mOnSurface
          }
          NText {
            text: completeMenuItem.text
            pointSize: Style.fontSizeS
            color: completeMenuArea.containsMouse ? Color.mOnHover : Color.mOnSurface
            Layout.fillWidth: true
          }
        }

        MouseArea {
          id: completeMenuArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            TaskService.completeTask(taskContextMenu.taskId);
            taskContextMenu.close();
          }
        }
      }

      MenuItem {
        id: deleteMenuItem
        text: I18n.tr("todolist.panel.delete")

        background: Rectangle {
          color: deleteMenuArea.containsMouse ? Color.mHover : Color.transparent
          radius: Style.radiusXS
        }

        contentItem: RowLayout {
          spacing: Style.marginS
          NIcon {
            icon: "trash"
            pointSize: Style.fontSizeM
            color: deleteMenuArea.containsMouse ? Color.mOnHover : Color.mOnSurface
          }
          NText {
            text: deleteMenuItem.text
            pointSize: Style.fontSizeS
            color: deleteMenuArea.containsMouse ? Color.mOnHover : Color.mOnSurface
            Layout.fillWidth: true
          }
        }

        MouseArea {
          id: deleteMenuArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            TaskService.deleteTask(taskContextMenu.taskId);
            taskContextMenu.close();
          }
        }
      }
    }
  }
}
