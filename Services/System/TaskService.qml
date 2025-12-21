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
  property var inboxTasks: []      // No tags, no scheduled, no due
  property var todayTasks: []      // Due today or scheduled for today
  property var upcomingTasks: []   // Scheduled for future
  property var anytimeTasks: []    // Not time-bound, not inbox/someday
  property var somedayTasks: []    // Has +someday tag or status:waiting
  property var completedTasks: []  // Completed tasks (limited)

  // Smart list counts
  property int inboxCount: inboxTasks.length
  property int todayCount: todayTasks.length
  property int upcomingCount: upcomingTasks.length
  property int anytimeCount: anytimeTasks.length
  property int somedayCount: somedayTasks.length

  // Organization data
  property var tags: []

  // Currently selected list/filter
  property string currentFilter: "inbox"
  property string currentTag: ""

	  // Get tasks for current filter
	  readonly property var currentTasks: {
	    switch (currentFilter) {
	      case "inbox": return inboxTasks;
	      case "today": return todayTasks;
	      case "upcoming": return upcomingTasks;
	      case "anytime": return anytimeTasks;
	      case "someday": return somedayTasks;
	      case "completed": return completedTasks;
	      case "tag": {
	        var byTag = [];
	        for (var j = 0; j < tasks.length; j++) {
	          var task2 = tasks[j];
	          if (task2 && task2.tags && task2.tags.indexOf(currentTag) !== -1) byTag.push(task2);
	        }
	        return byTag;
	      }
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

    // Taskwarrior expects words/modifiers as separate argv tokens (e.g. `project:Work`, `+tag`,
    // `scheduled:today`). Passing a single argv string containing spaces can lead to attributes
    // being parsed and the description being dropped depending on task parsing behavior.
	    var rawTokens = description.trim().split(/\s+/);
	    var tokens = [];
	    for (var i = 0; i < rawTokens.length; i++) {
	      if (rawTokens[i] && rawTokens[i].length > 0) tokens.push(rawTokens[i]);
	    }
	    var cmd = ["task", "add"];
	    for (var j = 0; j < tokens.length; j++) {
	      cmd.push(tokens[j]);
	    }

    taskAdder.callback = callback;
    taskAdder.command = cmd;
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
      // Taskwarrior tag add/remove uses +tag / -tag (no colon).
      if (key === "+" || key === "-") {
        if (value !== null && value !== undefined && value !== "") {
          args.push(key + String(value));
        }
        continue;
      }
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

  // Load completed tasks (for completed view)
  function loadCompletedTasks() {
    if (!isAvailable || !isInitialized) return;
    completedLoader.running = true;
  }

  // Load tags list
  function loadTags() {
    if (!isAvailable || !isInitialized) return;
    tagsLoader.running = true;
  }

  // Set filter and load appropriate data
  function setFilter(filter, value) {
    currentFilter = filter;
    if (filter === "tag") {
      currentTag = value || "";
    }

    // Load completed tasks when viewing completed
    if (filter === "completed" && completedTasks.length === 0) {
      loadCompletedTasks();
    }
  }

	  // Helper to check if date is today
	  function _isToday(dateStr) {
	    var taskDate = _parseTaskDate(dateStr);
	    if (!taskDate) return false;
	    var now = new Date();
	    return taskDate.getFullYear() === now.getFullYear() &&
	           taskDate.getMonth() === now.getMonth() &&
	           taskDate.getDate() === now.getDate();
	  }

	  // Helper to check if date is in the future
	  function _isFuture(dateStr) {
	    var taskDate = _parseTaskDate(dateStr);
	    if (!taskDate) return false;
	    var today = new Date();
	    today.setHours(0, 0, 0, 0);
	    return taskDate > today;
	  }

	  // Parse Taskwarrior date formats into a local Date.
	  // Common export formats:
	  // - YYYYMMDDTHHMMSSZ (UTC)
	  // - YYYYMMDD (date only)
	  // - YYYY-MM-DD (user input; treated as local date)
	  function _parseTaskDate(dateStr) {
	    if (!dateStr) return null;
	    var s = String(dateStr);

	    // YYYYMMDDTHHMMSSZ
	    if (s.length >= 16 && s.charAt(8) === "T" && s.charAt(15) === "Z") {
	      var y = parseInt(s.substring(0, 4));
	      var mo = parseInt(s.substring(4, 6)) - 1;
	      var d = parseInt(s.substring(6, 8));
	      var hh = parseInt(s.substring(9, 11));
	      var mm = parseInt(s.substring(11, 13));
	      var ss = parseInt(s.substring(13, 15));
	      if (isNaN(y) || isNaN(mo) || isNaN(d) || isNaN(hh) || isNaN(mm) || isNaN(ss)) return null;
	      return new Date(Date.UTC(y, mo, d, hh, mm, ss));
	    }

	    // YYYYMMDD
	    if (s.length >= 8) {
	      var y2 = parseInt(s.substring(0, 4));
	      var mo2 = parseInt(s.substring(4, 6)) - 1;
	      var d2 = parseInt(s.substring(6, 8));
	      if (!isNaN(y2) && !isNaN(mo2) && !isNaN(d2)) {
	        return new Date(y2, mo2, d2);
	      }
	    }

	    // Fallback: try Date parsing
	    var dt = new Date(s);
	    if (isNaN(dt.getTime())) return null;
	    return dt;
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
	      if (task.tags && task.tags.indexOf("someday") !== -1) {
	        someday.push(task);
	        continue;
	      }

      var hasDue = !!task.due;
      var hasScheduled = !!task.scheduled;
      var hasTags = !!(task.tags && task.tags.length > 0);

      // Today: due today or scheduled today
      if ((hasDue && _isToday(task.due)) || (hasScheduled && _isToday(task.scheduled))) {
        today.push(task);
        continue;
      }

      // Upcoming: scheduled for future (not due today)
      // Also include tasks with a due date in the future.
      if ((hasScheduled && _isFuture(task.scheduled)) || (hasDue && _isFuture(task.due))) {
        upcoming.push(task);
        continue;
      }

      // Inbox: no tags, no scheduled, no due
      if (!hasScheduled && !hasDue && !hasTags) {
        inbox.push(task);
        continue;
      }

      // Anytime: not time-bound (and not inbox/someday)
      if (!hasScheduled && !hasDue) {
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

  // Process to load tags
  Process {
    id: tagsLoader
    command: ["task", "_tags"]
    running: false

	    onExited: function(exitCode) {
	      if (exitCode === 0) {
	        var raw = stdout.text.trim();
	        var split = (raw === "") ? [] : raw.split("\n");
	        var lines = [];
	        for (var i = 0; i < split.length; i++) {
	          var line = split[i].trim();
	          if (line === "" || line === "someday") continue;
	          lines.push(line);
	        }
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
