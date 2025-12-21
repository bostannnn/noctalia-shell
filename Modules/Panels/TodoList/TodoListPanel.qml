import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.MainScreen
import qs.Services.System
import qs.Services.UI
import qs.Widgets

/**
 * Things 3-inspired task manager panel.
 * Features sidebar navigation with smart lists, main task view, and detail editor.
 */
SmartPanel {
    id: root

    preferredWidth: Math.round(800 * Style.uiScaleRatio)
    preferredHeight: Math.round(600 * Style.uiScaleRatio)

    // Selected task for detail view
    property var selectedTask: null
    property int selectedIndex: -1
    property string selectedTaskId: ""

    panelContent: Item {
        id: contentRoot
        anchors.fill: parent

        readonly property real contentPreferredHeight: root.preferredHeight

        // Auto-focus input when panel opens
        Connections {
            target: root
            function onOpened() {
                addInput.forceActiveFocus();
                TaskService.loadTasks(true);
            }
            function onClosed() {
                root.selectedTask = null;
                root.selectedIndex = -1;
                root.selectedTaskId = "";
            }
        }

        Connections {
            target: TaskService
            function onTasksUpdated() {
                root._restoreSelection();
            }
        }

        // Keyboard navigation
        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Escape) {
                if (root.selectedTask) {
                    root.selectedTask = null;
                    root.selectedIndex = -1;
                    root.selectedTaskId = "";
                    event.accepted = true;
                } else {
                    root.close();
                    event.accepted = true;
                }
                return;
            }

            // Navigate tasks with arrow keys
            var tasks = TaskService.currentTasks || [];
            if (tasks.length === 0)
                return;

            if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                if (root.selectedIndex < tasks.length - 1) {
                    root.selectedIndex++;
                    root.selectedTask = tasks[root.selectedIndex];
                    root.selectedTaskId = root.selectedTask ? root.selectedTask.id : "";
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                if (root.selectedIndex > 0) {
                    root.selectedIndex--;
                    root.selectedTask = tasks[root.selectedIndex];
                    root.selectedTaskId = root.selectedTask ? root.selectedTask.id : "";
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Return && root.selectedTask) {
                // Open detail view or toggle complete
                if (event.modifiers & Qt.ControlModifier) {
                    TaskService.completeTask(root.selectedTask.id.toString());
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Space && root.selectedTask) {
                TaskService.completeTask(root.selectedTask.id.toString());
                event.accepted = true;
            }

            // Smart list shortcuts (Ctrl+1-6)
            if (event.modifiers & Qt.ControlModifier) {
                var filters = ["inbox", "today", "upcoming", "anytime", "someday", "completed"];
                var num = event.key - Qt.Key_1;
                if (num >= 0 && num < filters.length) {
                    TaskService.setFilter(filters[num]);
                    root.selectedTask = null;
                    root.selectedIndex = -1;
                    root.selectedTaskId = "";
                    event.accepted = true;
                }
            }

            // New task shortcut
            if (event.key === Qt.Key_N && (event.modifiers & Qt.ControlModifier)) {
                addInput.forceActiveFocus();
                event.accepted = true;
            }
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // Sidebar
            Rectangle {
                id: sidebar
                Layout.preferredWidth: Math.round(180 * Style.uiScaleRatio)
                Layout.fillHeight: true
                color: Color.mSurfaceVariant
                radius: Style.radiusM

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Style.marginM
                    spacing: Style.marginS

                    // Smart lists
                    Repeater {
                        model: [
                            {
                                id: "inbox",
                                icon: "inbox",
                                label: I18n.tr("todolist.filter.inbox"),
                                count: TaskService.inboxCount
                            },
                            {
                                id: "today",
                                icon: "star",
                                label: I18n.tr("todolist.filter.today"),
                                count: TaskService.todayCount
                            },
                            {
                                id: "upcoming",
                                icon: "calendar",
                                label: I18n.tr("todolist.filter.upcoming"),
                                count: TaskService.upcomingCount
                            },
                            {
                                id: "anytime",
                                icon: "layers-linked",
                                label: I18n.tr("todolist.filter.anytime"),
                                count: TaskService.anytimeCount
                            },
                            {
                                id: "someday",
                                icon: "archive",
                                label: I18n.tr("todolist.filter.someday"),
                                count: TaskService.somedayCount
                            },
                            {
                                id: "completed",
                                icon: "circle-check",
                                label: I18n.tr("todolist.filter.completed"),
                                count: 0
                            }
                        ]
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            height: filterRow.implicitHeight + Style.marginS * 2
                            radius: Style.radiusS
                            color: TaskService.currentFilter === modelData.id ? Qt.alpha(Color.mPrimary, 0.18) : (filterArea.containsMouse ? Color.mHover : Color.transparent)

                            RowLayout {
                                id: filterRow
                                anchors.fill: parent
                                anchors.margins: Style.marginS
                                spacing: Style.marginS

                                NIcon {
                                    icon: modelData.icon
                                    pointSize: Style.fontSizeM
                                    color: TaskService.currentFilter === modelData.id ? Color.mPrimary : Color.mOnSurfaceVariant
                                }

                                NText {
                                    text: modelData.label
                                    pointSize: Style.fontSizeS
                                    color: Color.mOnSurface
                                    Layout.fillWidth: true
                                }

                                NText {
                                    visible: modelData.count > 0
                                    text: modelData.count
                                    pointSize: Style.fontSizeXS
                                    color: Color.mOnSurfaceVariant
                                }
                            }

                            MouseArea {
                                id: filterArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    TaskService.setFilter(modelData.id);
                                    root.selectedTask = null;
                                    root.selectedIndex = -1;
                                }
                            }
                        }
                    }

                    // Separator
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Color.mOutline
                        Layout.topMargin: Style.marginS
                        Layout.bottomMargin: Style.marginS
                    }

                    // Tags section
                    NText {
                        text: I18n.tr("todolist.section.tags")
                        pointSize: Style.fontSizeXS
                        color: Color.mOnSurfaceVariant
                        font.weight: Font.Medium
                        Layout.topMargin: Style.marginS
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 4
                        visible: TaskService.tags.length > 0

                        Repeater {
                            model: TaskService.tags.slice(0, 8)
                            delegate: Rectangle {
                                width: tagLabel.implicitWidth + Style.marginS * 2
                                height: tagLabel.implicitHeight + 4
                                radius: Style.radiusXS
                                color: (TaskService.currentFilter === "tag" && TaskService.currentTag === modelData) ? Qt.alpha(Color.mTertiary, 0.18) : (tagArea.containsMouse ? Color.mHover : Color.mSurfaceVariant)

                                NText {
                                    id: tagLabel
                                    anchors.centerIn: parent
                                    text: modelData
                                    pointSize: Style.fontSizeXS
                                    color: Color.mOnSurface
                                }

                                MouseArea {
                                    id: tagArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        TaskService.setFilter("tag", modelData);
                                        root.selectedTask = null;
                                        root.selectedIndex = -1;
                                    }
                                }
                            }
                        }
                    }

                    NText {
                        visible: TaskService.tags.length === 0
                        text: I18n.tr("todolist.section.no-tags")
                        pointSize: Style.fontSizeXS
                        color: Color.mOnSurfaceVariant
                        opacity: 0.7
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }

            // Main content
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Color.mSurface
                radius: Style.radiusM

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Style.marginL
                    spacing: Style.marginM

                    // Header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.marginS

                        NText {
                            text: _getFilterTitle()
                            pointSize: Style.fontSizeL
                            font.weight: Style.fontWeightBold
                            color: Color.mOnSurface
                            Layout.fillWidth: true
                        }

                        NIconButton {
                            icon: "refresh"
                            baseSize: 28
                            onClicked: TaskService.loadTasks(true)
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
                                font.pixelSize: Style.fontSizeM * Style.uiScaleRatio
                                font.weight: Style.fontWeightMedium
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
                                        _addTaskWithContext(text.trim());
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
                                        _addTaskWithContext(addInput.text.trim());
                                        addInput.text = "";
                                    }
                                }
                            }
                        }
                    }

                    // Task count
                    NText {
                        visible: TaskService.currentTasks.length > 0
                        text: I18n.tr("todolist.panel.count", {
                            "count": TaskService.currentTasks.length
                        })
                        pointSize: Style.fontSizeXS
                        color: Color.mOnSurfaceVariant
                    }

                    // Main content area with task list and optional detail panel
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: Style.marginM

                        // Task list
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            NListView {
                                id: taskListView
                                anchors.fill: parent
                                spacing: 2
                                model: TaskService.currentTasks
                                visible: TaskService.currentTasks.length > 0
                                horizontalPolicy: ScrollBar.AlwaysOff
                                verticalPolicy: ScrollBar.AsNeeded

                                delegate: TaskItem {
                                    required property var modelData
                                    required property int index

                                    width: taskListView.width
                                    taskData: modelData
                                    selected: !!(root.selectedTask && modelData && root.selectedTask.id === modelData.id)

                                    onClicked: {
                                        var task = modelData;
                                        root.selectedTask = task;
                                        root.selectedIndex = index;
                                        root.selectedTaskId = task ? task.id : "";
                                    }

                                    onCheckboxClicked: {
                                        var task = modelData;
                                        if (!task)
                                            return;
                                        if (task.status === "completed") {
                                            // Uncomplete - not directly supported, would need to re-add
                                        } else {
                                            TaskService.completeTask(task.id.toString());
                                        }
                                    }

                                    onDeleteClicked: {
                                        var task = modelData;
                                        if (!task)
                                            return;
                                        TaskService.deleteTask(task.id.toString());
                                        if (root.selectedTask && root.selectedTask.id === task.id) {
                                            root.selectedTask = null;
                                            root.selectedIndex = -1;
                                            root.selectedTaskId = "";
                                        }
                                    }
                                }
                            }

                            // Empty state
                            Column {
                                anchors.centerIn: parent
                                spacing: Style.marginM
                                visible: TaskService.currentTasks.length === 0 && !TaskService.loading

                                NIcon {
                                    icon: _getEmptyIcon()
                                    pointSize: Style.fontSizeXXL
                                    color: Color.mOnSurfaceVariant
                                    opacity: 0.5
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                NText {
                                    text: TaskService.isAvailable ? _getEmptyMessage() : I18n.tr("todolist.panel.not-available")
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

                        // Detail panel (shown when task selected)
                        TaskDetails {
                            id: detailPanel
                            Layout.preferredWidth: root.selectedTask ? Math.round(360 * Style.uiScaleRatio) : 0
                            Layout.fillHeight: true
                            taskData: root.selectedTask
                            visible: root.selectedTask !== null

                            onCloseRequested: {
                                root.selectedTask = null;
                                root.selectedIndex = -1;
                                root.selectedTaskId = "";
                            }

                            Behavior on Layout.preferredWidth {
                                NumberAnimation {
                                    duration: Style.animationNormal
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Helper functions
    function _getFilterTitle() {
        switch (TaskService.currentFilter) {
        case "inbox":
            return I18n.tr("todolist.filter.inbox");
        case "today":
            return I18n.tr("todolist.filter.today");
        case "upcoming":
            return I18n.tr("todolist.filter.upcoming");
        case "anytime":
            return I18n.tr("todolist.filter.anytime");
        case "someday":
            return I18n.tr("todolist.filter.someday");
        case "completed":
            return I18n.tr("todolist.filter.completed");
        case "tag":
            return "#" + TaskService.currentTag;
        default:
            return I18n.tr("todolist.panel.title");
        }
    }

    function _getEmptyIcon() {
        switch (TaskService.currentFilter) {
        case "inbox":
            return "inbox";
        case "today":
            return "star";
        case "upcoming":
            return "calendar";
        case "anytime":
            return "layers-linked";
        case "someday":
            return "archive";
        case "completed":
            return "circle-check";
        default:
            return "checklist";
        }
    }

    function _getEmptyMessage() {
        switch (TaskService.currentFilter) {
        case "inbox":
            return I18n.tr("todolist.empty.inbox");
        case "today":
            return I18n.tr("todolist.empty.today");
        case "upcoming":
            return I18n.tr("todolist.empty.upcoming");
        case "anytime":
            return I18n.tr("todolist.empty.anytime");
        case "someday":
            return I18n.tr("todolist.empty.someday");
        case "completed":
            return I18n.tr("todolist.empty.completed");
        default:
            return I18n.tr("todolist.panel.empty");
        }
    }

    function _addTaskWithContext(description) {
        // Add task with context based on current filter
        var filter = TaskService.currentFilter;

        if (filter === "today") {
            TaskService.addTask(description + " scheduled:today");
        } else if (filter === "someday") {
            TaskService.addTask(description + " +someday");
        } else if (filter === "tag" && TaskService.currentTag) {
            TaskService.addTask(description + " +" + TaskService.currentTag);
        } else {
            TaskService.addTask(description);
        }
    }

    function _restoreSelection() {
        if (!root.selectedTaskId)
            return;

        var tasks = TaskService.currentTasks || [];
        for (var i = 0; i < tasks.length; i++) {
            var t = tasks[i];
            if (t && String(t.id) === String(root.selectedTaskId)) {
                root.selectedTask = t;
                root.selectedIndex = i;
                return;
            }
        }

        root.selectedTask = null;
        root.selectedIndex = -1;
        root.selectedTaskId = "";
    }
}
