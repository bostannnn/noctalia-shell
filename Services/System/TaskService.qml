pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.System

// Service for Taskwarrior integration with Things 3-style smart lists
Singleton {
  id: root

  // Task data - all pending tasks
  property var tasks: []
  property int pendingCount: 0
  property bool loading: false
  property string lastError: ""

  // Smart list filtered tasks
  property var inboxTasks: []      // No project, no scheduled, no due
  property var todayTasks: []      // Due today or scheduled for today
  property var upcomingTasks: []   // Scheduled for future
  property var anytimeTasks: []    // Has project but no scheduled/due
  property var somedayTasks: []    // Has +someday tag or status:waiting
  property var completedTasks: []  // Completed tasks (limited)

  // Smart list counts
  property int inboxCount: inboxTasks.length
  property int todayCount: todayTasks.length
  property int upcomingCount: upcomingTasks.length
  property int anytimeCount: anytimeTasks.length
  property int somedayCount: somedayTasks.length

  // Organization data
  property var projects: []
  property var tags: []

  // Currently selected list/filter
  property string currentFilter: "inbox"
  property string currentProject: ""
  property string currentTag: ""

  // Get tasks for current filter
  readonly property var currentTasks: {
    switch (currentFilter) {
      case "inbox": return inboxTasks;
      case "today": return todayTasks;
      case "upcoming": return upcomingTasks;
      case "anytime": return anytimeTasks;
      case "someday": return somedayTasks;
      case "logbook": return completedTasks;
      case "project": return tasks.filter(t => t.project === currentProject);
      case "tag": return tasks.filter(t => t.tags && t.tags.includes(currentTag));
      default: return tasks;
    }
  }

  // Check if taskwarrior is available
  property bool isAvailable: ProgramCheckerService.taskwarriorAvailable

  // Track if taskwarrior has been initialized (has config)
  property bool isInitialized: false
  property bool initChecked: false

  signal tasksUpdated()
  signal taskAdded(string taskId)
  signal taskCompleted(string taskId)
  signal taskDeleted(string taskId)
  signal taskModified(string taskId)
  signal projectsLoaded()
  signal tagsLoaded()

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
    // Use rc.confirmation:off to avoid shell injection risks
    taskDeleter.command = ["task", "rc.confirmation:off", taskId, "delete"];
    taskDeleter.running = true;
  }

  // Modify a task (update properties)
  function modifyTask(taskId, modifications, callback) {
    if (!isAvailable || !taskId || !modifications) {
      if (callback) callback(false);
      return;
    }

    var args = ["task", "rc.confirmation:off", taskId, "modify"];
    // modifications is an object like { project: "Work", due: "tomorrow" }
    for (var key in modifications) {
      var value = modifications[key];
      if (value === null || value === "") {
        // Clear the attribute
        args.push(key + ":");
      } else {
        args.push(key + ":" + value);
      }
    }

    taskModifier.taskId = taskId;
    taskModifier.callback = callback;
    taskModifier.command = args;
    taskModifier.running = true;
  }

  // Add annotation (note) to a task
  function addAnnotation(taskId, annotation, callback) {
    if (!isAvailable || !taskId || !annotation.trim()) {
      if (callback) callback(false);
      return;
    }

    annotationAdder.taskId = taskId;
    annotationAdder.callback = callback;
    annotationAdder.command = ["task", taskId, "annotate", annotation.trim()];
    annotationAdder.running = true;
  }

  // Load completed tasks (for logbook)
  function loadCompletedTasks() {
    if (!isAvailable || !isInitialized) return;
    completedLoader.running = true;
  }

  // Load projects list
  function loadProjects() {
    if (!isAvailable || !isInitialized) return;
    projectsLoader.running = true;
  }

  // Load tags list
  function loadTags() {
    if (!isAvailable || !isInitialized) return;
    tagsLoader.running = true;
  }

  // Set filter and load appropriate data
  function setFilter(filter, value) {
    currentFilter = filter;
    if (filter === "project") {
      currentProject = value || "";
    } else if (filter === "tag") {
      currentTag = value || "";
    }

    // Load completed tasks when viewing logbook
    if (filter === "logbook" && completedTasks.length === 0) {
      loadCompletedTasks();
    }
  }

  // Helper to check if date is today
  function _isToday(dateStr) {
    if (!dateStr) return false;
    var taskDate = new Date(dateStr.substring(0, 4) + "-" + dateStr.substring(4, 6) + "-" + dateStr.substring(6, 8));
    var today = new Date();
    return taskDate.toDateString() === today.toDateString();
  }

  // Helper to check if date is in the future
  function _isFuture(dateStr) {
    if (!dateStr) return false;
    var taskDate = new Date(dateStr.substring(0, 4) + "-" + dateStr.substring(4, 6) + "-" + dateStr.substring(6, 8));
    var today = new Date();
    today.setHours(0, 0, 0, 0);
    return taskDate > today;
  }

  // Filter tasks into smart lists
  function _filterTasks() {
    var inbox = [];
    var today = [];
    var upcoming = [];
    var anytime = [];
    var someday = [];

    for (var i = 0; i < tasks.length; i++) {
      var task = tasks[i];

      // Skip waiting tasks for most lists
      if (task.status === "waiting") {
        someday.push(task);
        continue;
      }

      // Check for someday tag
      if (task.tags && task.tags.includes("someday")) {
        someday.push(task);
        continue;
      }

      var hasDue = !!task.due;
      var hasScheduled = !!task.scheduled;
      var hasProject = !!task.project;

      // Today: due today or scheduled today
      if ((hasDue && _isToday(task.due)) || (hasScheduled && _isToday(task.scheduled))) {
        today.push(task);
        continue;
      }

      // Upcoming: scheduled for future (not due today)
      if (hasScheduled && _isFuture(task.scheduled)) {
        upcoming.push(task);
        continue;
      }

      // Inbox: no project, no scheduled, no due
      if (!hasProject && !hasScheduled && !hasDue) {
        inbox.push(task);
        continue;
      }

      // Anytime: has project or due date, but not scheduled
      if (!hasScheduled && (hasProject || hasDue)) {
        anytime.push(task);
        continue;
      }

      // Default to anytime
      anytime.push(task);
    }

    inboxTasks = inbox;
    todayTasks = today;
    upcomingTasks = upcoming;
    anytimeTasks = anytime;
    somedayTasks = someday;

    Logger.d("TaskService", "Filtered tasks - Inbox:", inbox.length, "Today:", today.length,
             "Upcoming:", upcoming.length, "Anytime:", anytime.length, "Someday:", someday.length);
  }

  // Extract unique projects from tasks
  function _extractProjects() {
    var projectSet = {};
    for (var i = 0; i < tasks.length; i++) {
      if (tasks[i].project) {
        projectSet[tasks[i].project] = true;
      }
    }
    projects = Object.keys(projectSet).sort();
    projectsLoaded();
  }

  // Extract unique tags from tasks
  function _extractTags() {
    var tagSet = {};
    for (var i = 0; i < tasks.length; i++) {
      if (tasks[i].tags) {
        for (var j = 0; j < tasks[i].tags.length; j++) {
          var tag = tasks[i].tags[j];
          if (tag !== "someday") {  // Don't show someday as a tag
            tagSet[tag] = true;
          }
        }
      }
    }
    tags = Object.keys(tagSet).sort();
    tagsLoaded();
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

          // Filter into smart lists and extract metadata
          root._filterTasks();
          root._extractProjects();
          root._extractTags();
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
        root.lastError = "";
        root.loadTasks();
        root.taskAdded("");
      } else {
        root.lastError = "Failed to add task";
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
        root.lastError = "";
        root.loadTasks();
        root.taskCompleted(taskId);
      } else {
        root.lastError = "Failed to complete task";
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
        root.lastError = "";
        root.loadTasks();
        root.taskDeleted(taskId);
      } else {
        root.lastError = "Failed to delete task";
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

  // Process to modify tasks
  Process {
    id: taskModifier
    running: false
    property string taskId: ""
    property var callback: null

    onExited: function(exitCode) {
      var success = (exitCode === 0);
      if (success) {
        Logger.d("TaskService", "Task modified:", taskId);
        root.lastError = "";
        root.loadTasks();
        root.taskModified(taskId);
      } else {
        root.lastError = "Failed to modify task";
        Logger.e("TaskService", "Failed to modify task:", stderr.text);
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

  // Process to add annotations
  Process {
    id: annotationAdder
    running: false
    property string taskId: ""
    property var callback: null

    onExited: function(exitCode) {
      var success = (exitCode === 0);
      if (success) {
        Logger.d("TaskService", "Annotation added to task:", taskId);
        root.lastError = "";
        root.loadTasks();
      } else {
        root.lastError = "Failed to add annotation";
        Logger.e("TaskService", "Failed to add annotation:", stderr.text);
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

  // Process to load completed tasks
  Process {
    id: completedLoader
    command: ["task", "status:completed", "limit:50", "export"]
    running: false

    onExited: function(exitCode) {
      if (exitCode === 0) {
        try {
          var jsonStr = stdout.text.trim();
          if (jsonStr === "" || jsonStr === "[]") {
            root.completedTasks = [];
          } else {
            root.completedTasks = JSON.parse(jsonStr);
          }
          Logger.d("TaskService", "Loaded", root.completedTasks.length, "completed tasks");
        } catch (e) {
          Logger.e("TaskService", "Failed to parse completed tasks:", e.toString());
          root.completedTasks = [];
        }
      } else {
        Logger.e("TaskService", "Failed to load completed tasks:", stderr.text);
      }
    }

    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }

  // Process to load projects
  Process {
    id: projectsLoader
    command: ["task", "_projects"]
    running: false

    onExited: function(exitCode) {
      if (exitCode === 0) {
        var lines = stdout.text.trim().split("\n").filter(l => l.trim() !== "");
        root.projects = lines;
        Logger.d("TaskService", "Loaded", root.projects.length, "projects");
        root.projectsLoaded();
      } else {
        Logger.e("TaskService", "Failed to load projects:", stderr.text);
      }
    }

    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }

  // Process to load tags
  Process {
    id: tagsLoader
    command: ["task", "_tags"]
    running: false

    onExited: function(exitCode) {
      if (exitCode === 0) {
        var lines = stdout.text.trim().split("\n").filter(l => l.trim() !== "" && l !== "someday");
        root.tags = lines;
        Logger.d("TaskService", "Loaded", root.tags.length, "tags");
        root.tagsLoaded();
      } else {
        Logger.e("TaskService", "Failed to load tags:", stderr.text);
      }
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
