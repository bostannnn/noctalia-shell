pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Service for Taskwarrior integration
Singleton {
  id: root

  // Task data
  property var tasks: []
  property int pendingCount: 0
  property int completedCount: 0
  property bool loading: false
  property string lastError: ""

  // Check if taskwarrior is available
  property bool isAvailable: ProgramCheckerService.taskwarriorAvailable

  // Track if taskwarrior has been initialized (has config)
  property bool isInitialized: false
  property bool initChecked: false

  signal tasksUpdated()
  signal taskAdded(string taskId)
  signal taskCompleted(string taskId)
  signal taskDeleted(string taskId)

  // Check if taskwarrior config exists
  function checkInitialized() {
    if (!isAvailable) return;
    initChecker.running = true;
  }

  // Initialize taskwarrior (creates ~/.taskrc and ~/.task)
  function initializeTaskwarrior() {
    if (!isAvailable || isInitialized) return;
    Logger.i("TaskService", "Initializing Taskwarrior for first use...");
    taskInitializer.running = true;
  }

  // Load all pending tasks from Taskwarrior
  function loadTasks() {
    if (!isAvailable) {
      lastError = "Taskwarrior is not installed";
      return;
    }

    // If not initialized yet, initialize first
    if (initChecked && !isInitialized) {
      initializeTaskwarrior();
      return;
    }

    if (loading) return;
    loading = true;
    lastError = "";

    taskLoader.running = true;
  }

  // Add a new task
  function addTask(description, callback) {
    if (!isAvailable || !description.trim()) {
      if (callback) callback(false);
      return;
    }

    taskAdder.callback = callback;
    taskAdder.command = ["task", "add", description.trim()];
    taskAdder.running = true;
  }

  // Complete a task by ID
  function completeTask(taskId, callback) {
    if (!isAvailable || !taskId) {
      if (callback) callback(false);
      return;
    }

    taskCompleter.taskId = taskId;
    taskCompleter.callback = callback;
    taskCompleter.command = ["task", taskId, "done"];
    taskCompleter.running = true;
  }

  // Delete a task by ID
  function deleteTask(taskId, callback) {
    if (!isAvailable || !taskId) {
      if (callback) callback(false);
      return;
    }

    taskDeleter.taskId = taskId;
    taskDeleter.callback = callback;
    taskDeleter.command = ["sh", "-c", "echo 'yes' | task " + taskId + " delete"];
    taskDeleter.running = true;
  }

  // Process to load tasks
  Process {
    id: taskLoader
    command: ["task", "status:pending", "export"]
    running: false

    onExited: function(exitCode) {
      root.loading = false;

      if (exitCode === 0) {
        try {
          var jsonStr = stdout.text.trim();
          if (jsonStr === "" || jsonStr === "[]") {
            root.tasks = [];
          } else {
            root.tasks = JSON.parse(jsonStr);
          }
          root.pendingCount = root.tasks.length;
          root.lastError = "";
          Logger.d("TaskService", "Loaded", root.pendingCount, "tasks");
        } catch (e) {
          root.lastError = "Failed to parse tasks: " + e.toString();
          Logger.e("TaskService", root.lastError);
          root.tasks = [];
          root.pendingCount = 0;
        }
      } else {
        root.lastError = "Failed to load tasks";
        Logger.e("TaskService", root.lastError, stderr.text);
      }

      root.tasksUpdated();
    }

    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }

  // Process to add tasks
  Process {
    id: taskAdder
    running: false
    property var callback: null

    onExited: function(exitCode) {
      var success = (exitCode === 0);
      if (success) {
        Logger.d("TaskService", "Task added");
        root.loadTasks();
        root.taskAdded("");
      } else {
        Logger.e("TaskService", "Failed to add task:", stderr.text);
      }

      if (callback) {
        callback(success);
        callback = null;
      }
    }

    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }

  // Process to complete tasks
  Process {
    id: taskCompleter
    running: false
    property string taskId: ""
    property var callback: null

    onExited: function(exitCode) {
      var success = (exitCode === 0);
      if (success) {
        Logger.d("TaskService", "Task completed:", taskId);
        root.loadTasks();
        root.taskCompleted(taskId);
      } else {
        Logger.e("TaskService", "Failed to complete task:", stderr.text);
      }

      if (callback) {
        callback(success);
        callback = null;
      }
      taskId = "";
    }

    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }

  // Process to delete tasks
  Process {
    id: taskDeleter
    running: false
    property string taskId: ""
    property var callback: null

    onExited: function(exitCode) {
      var success = (exitCode === 0);
      if (success) {
        Logger.d("TaskService", "Task deleted:", taskId);
        root.loadTasks();
        root.taskDeleted(taskId);
      } else {
        Logger.e("TaskService", "Failed to delete task:", stderr.text);
      }

      if (callback) {
        callback(success);
        callback = null;
      }
      taskId = "";
    }

    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }

  // Process to check if taskwarrior is initialized (has ~/.taskrc)
  Process {
    id: initChecker
    command: ["sh", "-c", "test -f ~/.taskrc && echo 'yes' || echo 'no'"]
    running: false

    onExited: function(exitCode) {
      var result = stdout.text.trim();
      root.isInitialized = (result === "yes");
      root.initChecked = true;
      Logger.d("TaskService", "Taskwarrior initialized:", root.isInitialized);

      if (root.isInitialized) {
        root.loadTasks();
      }
    }

    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }

  // Process to initialize taskwarrior for first use
  Process {
    id: taskInitializer
    // Use 'yes' to auto-confirm config creation, then run a simple command
    command: ["sh", "-c", "yes | task rc.confirmation:off _version > /dev/null 2>&1"]
    running: false

    onExited: function(exitCode) {
      if (exitCode === 0) {
        Logger.i("TaskService", "Taskwarrior initialized successfully");
        root.isInitialized = true;
        root.loadTasks();
      } else {
        Logger.e("TaskService", "Failed to initialize Taskwarrior");
        root.lastError = "Failed to initialize Taskwarrior";
      }
    }

    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }

  // Auto-refresh timer
  Timer {
    id: refreshTimer
    interval: 60000 // Refresh every minute
    repeat: true
    running: root.isAvailable && root.isInitialized

    onTriggered: {
      root.loadTasks();
    }
  }

  // Initialize when service loads
  Component.onCompleted: {
    if (isAvailable) {
      Qt.callLater(checkInitialized);
    }
  }

  // Watch for availability changes
  Connections {
    target: ProgramCheckerService
    function onChecksCompleted() {
      if (ProgramCheckerService.taskwarriorAvailable && !root.initChecked) {
        root.checkInitialized();
      }
    }
  }
}
