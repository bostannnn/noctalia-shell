pragma Singleton

import QtQuick
import Quickshell
import qs.Commons

Singleton {
  id: root

  // State
  property bool fetching: false
  property bool initialSearchScheduled: false
  property var currentResults: []
  property var currentMeta: ({})
  property string lastError: ""
  property string currentQuery: ""
  property int currentPage: 1
  property int lastPage: 1

  // Search parameters
  property string categories: "111" // general,anime,people (all enabled by default)
  property string purity: "100" // sfw
  property string sorting: "relevance" // date_added, relevance, random, views, favorites, toplist
  property string order: "desc" // desc, asc
  property string topRange: "1M" // 1d, 3d, 1w, 1M, 3M, 6M, 1y
  property string seed: "" // For random sorting
  property string minResolution: "" // e.g., "1920x1080"
  property string resolutions: "" // e.g., "1920x1080,1920x1200"
  property string ratios: "" // e.g., "16x9,16x10"
  property string colors: "" // Color hex codes

  // Signals
  signal searchCompleted(var results, var meta)
  signal searchFailed(string error)
  signal wallpaperDownloaded(string wallpaperId, string localPath)

  // Base API URL
  readonly property string apiBaseUrl: "https://wallhaven.cc/api/v1"

  // Curated word list for random discovery (aesthetic, nature, abstract, etc.)
  readonly property var discoveryWords: [
    // Nature
    "sunset", "sunrise", "mountains", "ocean", "forest", "lake", "river", "waterfall",
    "aurora", "northern lights", "stars", "galaxy", "nebula", "cosmos", "moon", "clouds",
    "storm", "lightning", "rain", "snow", "winter", "autumn", "spring", "summer",
    "beach", "desert", "canyon", "valley", "cliff", "island", "tropical", "arctic",
    "flowers", "cherry blossom", "sakura", "trees", "bamboo", "meadow", "field",
    // Cities & Architecture
    "cityscape", "skyline", "night city", "tokyo", "new york", "paris", "london",
    "cyberpunk city", "futuristic city", "neon city", "rain city", "urban", "street",
    "architecture", "building", "skyscraper", "bridge", "temple", "castle", "ruins",
    // Abstract & Art
    "abstract", "minimal", "geometric", "fractal", "gradient", "colorful", "vibrant",
    "dark", "moody", "atmospheric", "ethereal", "dreamy", "surreal", "fantasy",
    "digital art", "concept art", "illustration", "painting", "artwork",
    // Sci-Fi & Fantasy
    "space", "spaceship", "planet", "alien", "sci-fi", "futuristic", "cyberpunk",
    "neon", "synthwave", "retrowave", "vaporwave", "outrun", "blade runner",
    "dragon", "magic", "wizard", "sword", "medieval", "mythology", "fairy tale",
    // Aesthetic moods
    "cozy", "peaceful", "serene", "calm", "tranquil", "mysterious", "epic",
    "dramatic", "cinematic", "beautiful", "stunning", "breathtaking", "majestic",
    "lonely", "solitude", "melancholy", "nostalgic", "vintage", "retro",
    // Colors
    "blue", "purple", "pink", "red", "orange", "golden", "green", "teal", "cyan",
    "black and white", "monochrome", "pastel", "neon colors", "warm colors", "cool colors",
    // Time & Light
    "golden hour", "blue hour", "twilight", "dusk", "dawn", "night", "midnight",
    "sunlight", "moonlight", "starlight", "candlelight", "firelight", "reflection",
    // Specific subjects
    "cat", "wolf", "eagle", "whale", "deer", "fox", "owl", "butterfly",
    "car", "motorcycle", "train", "airplane", "boat", "lighthouse",
    "coffee", "books", "music", "guitar", "piano", "rain on window",
    // Anime/Art styles
    "anime landscape", "anime scenery", "studio ghibli", "makoto shinkai",
    "lofi", "pixel art", "watercolor", "oil painting", "ink art",
    // Popular combinations
    "mountain sunset", "ocean waves", "forest path", "city rain", "space station",
    "cozy room", "rainy day", "starry night", "foggy forest", "snowy mountain"
  ]

  // Popular Wallhaven tags for random discovery
  readonly property var discoveryTags: [
    "landscape", "nature", "space", "city", "abstract", "anime", "fantasy",
    "sci-fi", "cyberpunk", "dark", "minimal", "colorful", "sunset", "night",
    "mountains", "ocean", "forest", "digital art", "artwork", "photography"
  ]

  // -------------------------------------------------
  function search(query, page) {
    if (fetching) {
      return;
    }

    // Reset initial search flag once we start a search
    if (initialSearchScheduled) {
      initialSearchScheduled = false;
    }

    fetching = true;
    lastError = "";
    currentQuery = query || "";
    currentPage = page || 1;

    var url = apiBaseUrl + "/search";
    var params = [];

    if (currentQuery) {
      params.push("q=" + encodeURIComponent(currentQuery));
    }

    params.push("categories=" + categories);
    params.push("purity=" + purity);
    params.push("sorting=" + sorting);
    params.push("order=" + order);

    if (sorting === "toplist") {
      params.push("topRange=" + topRange);
    }

    if (sorting === "random" && seed) {
      params.push("seed=" + seed);
    }

    if (minResolution) {
      params.push("atleast=" + minResolution);
    }

    if (resolutions) {
      params.push("resolutions=" + resolutions);
    }

    if (ratios) {
      params.push("ratios=" + ratios);
    }

    if (colors) {
      params.push("colors=" + colors);
    }

    params.push("page=" + currentPage);

    url += "?" + params.join("&");

    Logger.d("Wallhaven", "Searching:", url);

    var xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function () {
      if (xhr.readyState === XMLHttpRequest.DONE) {
        fetching = false;
        if (xhr.status === 200) {
          try {
            var response = JSON.parse(xhr.responseText);
            if (response.data && Array.isArray(response.data)) {
              currentResults = response.data;
              currentMeta = response.meta || {};
              lastPage = currentMeta.last_page || 1;

              // Store seed for random sorting
              if (currentMeta.seed) {
                seed = currentMeta.seed;
              }

              Logger.d("Wallhaven", "Search completed:", currentResults.length, "results, page", currentPage, "of", lastPage);
              searchCompleted(currentResults, currentMeta);
            } else {
              var errorMsg = "Invalid API response";
              lastError = errorMsg;
              Logger.e("Wallhaven", errorMsg);
              searchFailed(errorMsg);
            }
          } catch (e) {
            var errorMsg = "Failed to parse API response: " + e.toString();
            lastError = errorMsg;
            Logger.e("Wallhaven", errorMsg);
            searchFailed(errorMsg);
          }
        } else if (xhr.status === 429) {
          var errorMsg = "Rate limit exceeded (45 requests/minute)";
          lastError = errorMsg;
          Logger.w("Wallhaven", errorMsg);
          searchFailed(errorMsg);
        } else {
          var errorMsg = "API error: " + xhr.status;
          lastError = errorMsg;
          Logger.e("Wallhaven", "Search failed:", errorMsg);
          searchFailed(errorMsg);
        }
      }
    };

    xhr.open("GET", url);
    xhr.send();
  }

  // -------------------------------------------------
  function getWallpaperUrl(wallpaper) {
    // Use the 'path' field which contains the full resolution image URL
    if (wallpaper.path) {
      return wallpaper.path;
    }
    // Fallback to constructing URL from ID
    if (wallpaper.id) {
      var idPrefix = wallpaper.id.substring(0, 2);
      return "https://w.wallhaven.cc/full/" + idPrefix + "/wallhaven-" + wallpaper.id + ".jpg";
    }
    return "";
  }

  // -------------------------------------------------
  function getThumbnailUrl(wallpaper, size) {
    // size: "small", "large", "original"
    if (wallpaper.thumbs && wallpaper.thumbs[size]) {
      return wallpaper.thumbs[size];
    }
    // Fallback
    if (wallpaper.id) {
      var idPrefix = wallpaper.id.substring(0, 2);
      var sizeMap = {
        "small": "small",
        "large": "lg",
        "original": "orig"
      };
      var sizePath = sizeMap[size] || "lg";
      return "https://th.wallhaven.cc/" + sizePath + "/" + idPrefix + "/" + wallpaper.id + ".jpg";
    }
    return "";
  }

  // -------------------------------------------------
  function downloadWallpaper(wallpaper, callback) {
    var url = getWallpaperUrl(wallpaper);
    if (!url) {
      Logger.e("Wallhaven", "No URL available for wallpaper", wallpaper.id);
      if (callback)
        callback(false, "");
      return;
    }

    var wallpaperId = wallpaper.id;

    // Get the user's wallpaper directory
    var wallpaperDir = Settings.preprocessPath(Settings.data.wallpaper.directory);
    if (!wallpaperDir || wallpaperDir === "") {
      wallpaperDir = Settings.defaultWallpapersDirectory;
    }

    // Ensure directory ends with /
    if (!wallpaperDir.endsWith("/")) {
      wallpaperDir += "/";
    }

    var localPath = wallpaperDir + "wallhaven_" + wallpaperId + ".jpg";

    Logger.d("Wallhaven", "Downloading wallpaper", wallpaperId, "to", localPath);

    // Use curl or wget to download the file, ensuring directory exists first
    var downloadProcess = Qt.createQmlObject(`
                                             import QtQuick
                                             import Quickshell.Io
                                             Process {
                                             id: downloadProcess
                                             command: ["sh", "-c", "mkdir -p '` + wallpaperDir + `' && (curl -L -s -o '` + localPath + `' '` + url + `' || wget -q -O '` + localPath + `' '` + url + `')"]
                                             }
                                             `, root, "DownloadProcess_" + wallpaperId);

    downloadProcess.exited.connect(function (exitCode) {
      if (exitCode === 0) {
        Logger.i("Wallhaven", "Wallpaper downloaded:", localPath);
        wallpaperDownloaded(wallpaperId, localPath);
        if (callback)
          callback(true, localPath);
      } else {
        Logger.e("Wallhaven", "Failed to download wallpaper, exit code:", exitCode);
        if (callback)
          callback(false, "");
      }
      downloadProcess.destroy();
    });

    downloadProcess.running = true;
  }

  // -------------------------------------------------
  function reset() {
    currentResults = [];
    currentMeta = {};
    currentQuery = "";
    currentPage = 1;
    lastPage = 1;
    seed = "";
    lastError = "";
  }

  // -------------------------------------------------
  function nextPage() {
    if (currentPage < lastPage && !fetching) {
      search(currentQuery, currentPage + 1);
    }
  }

  // -------------------------------------------------
  function previousPage() {
    if (currentPage > 1 && !fetching) {
      search(currentQuery, currentPage - 1);
    }
  }

  // -------------------------------------------------
  // Generate a random search query for discovery
  function generateRandomQuery() {
    var query = "";

    // 70% chance to use a random word, 30% chance to use a tag
    if (Math.random() < 0.7) {
      // Pick 1-2 random words
      var numWords = Math.random() < 0.6 ? 1 : 2;
      var usedIndices = [];

      for (var i = 0; i < numWords; i++) {
        var idx;
        do {
          idx = Math.floor(Math.random() * discoveryWords.length);
        } while (usedIndices.indexOf(idx) !== -1);

        usedIndices.push(idx);
        if (query !== "") query += " ";
        query += discoveryWords[idx];
      }
    } else {
      // Pick a random tag
      var tagIdx = Math.floor(Math.random() * discoveryTags.length);
      query = discoveryTags[tagIdx];
    }

    return query;
  }

  // -------------------------------------------------
  // Discover random wallpapers with random query and sorting
  function discover() {
    if (fetching) {
      return;
    }

    // Generate random query
    var randomQuery = generateRandomQuery();

    // Store original sorting and set to random
    var originalSorting = sorting;
    sorting = "random";

    // Clear seed to get truly random results
    seed = "";

    Logger.d("Wallhaven", "Discovering with query:", randomQuery);

    // Perform search with random query
    search(randomQuery, 1);

    // Restore original sorting after search starts (for UI display)
    // The actual search already captured the "random" sorting
    Qt.callLater(function() {
      sorting = originalSorting;
    });
  }
}


