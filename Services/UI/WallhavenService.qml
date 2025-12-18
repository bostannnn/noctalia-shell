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

  // Anime-specific word list for anime discovery (500+ terms)
  readonly property var animeDiscoveryWords: [
    // Popular Anime Series
    "naruto", "one piece", "attack on titan", "demon slayer", "my hero academia",
    "jujutsu kaisen", "chainsaw man", "spy x family", "bleach", "dragon ball",
    "death note", "fullmetal alchemist", "hunter x hunter", "one punch man", "mob psycho",
    "code geass", "steins gate", "cowboy bebop", "samurai champloo", "trigun",
    "evangelion", "ghost in the shell", "akira", "tokyo ghoul", "parasyte",
    "violet evergarden", "your lie in april", "clannad", "anohana", "toradora",
    "sword art online", "re zero", "konosuba", "overlord", "no game no life",
    "fate stay night", "fate zero", "fate grand order", "monogatari", "bunny girl senpai",
    "kaguya sama", "quintessential quintuplets", "rent a girlfriend", "horimiya", "tonikawa",
    "bocchi the rock", "k-on", "lucky star", "nichijou", "daily lives of high school boys",
    "gintama", "grand blue", "komi can't communicate", "spy classroom", "oshi no ko",
    "frieren", "solo leveling", "blue lock", "haikyuu", "kuroko no basket",
    "slam dunk", "initial d", "wangan midnight", "yowamushi pedal", "run with the wind",
    "made in abyss", "promised neverland", "erased", "monster", "psycho pass",
    "black lagoon", "hellsing", "berserk", "vinland saga", "kingdom",
    "golden kamuy", "dororo", "mushishi", "natsume yuujinchou", "mononoke",
    "jojo bizarre adventure", "fist of the north star", "yu yu hakusho", "inuyasha", "rurouni kenshin",

    // Studio Ghibli
    "studio ghibli", "spirited away", "howl's moving castle", "princess mononoke", "my neighbor totoro",
    "kiki's delivery service", "castle in the sky", "nausicaa", "ponyo", "arrietty",
    "the wind rises", "porco rosso", "grave of the fireflies", "whisper of the heart", "only yesterday",

    // Makoto Shinkai
    "makoto shinkai", "your name", "weathering with you", "5 centimeters per second", "garden of words",
    "suzume", "children who chase lost voices", "she and her cat", "voices of a distant star",

    // Anime Aesthetics
    "anime aesthetic", "anime scenery", "anime landscape", "anime city", "anime night",
    "anime sunset", "anime sunrise", "anime sky", "anime clouds", "anime stars",
    "anime rain", "anime snow", "anime cherry blossom", "anime sakura", "anime spring",
    "anime summer", "anime autumn", "anime winter", "anime beach", "anime ocean",
    "anime forest", "anime mountains", "anime countryside", "anime village", "anime shrine",
    "anime temple", "anime school", "anime classroom", "anime rooftop", "anime train station",
    "anime train", "anime subway", "anime street", "anime alley", "anime market",
    "anime cafe", "anime room", "anime bedroom", "anime window", "anime balcony",

    // Anime Art Styles
    "anime art", "anime wallpaper", "anime background", "anime illustration", "anime digital art",
    "anime painting", "anime watercolor", "anime pastel", "anime vibrant", "anime colorful",
    "anime dark", "anime moody", "anime atmospheric", "anime dreamy", "anime ethereal",
    "anime fantasy", "anime magical", "anime mystical", "anime surreal", "anime abstract",
    "lofi anime", "vaporwave anime", "synthwave anime", "retrowave anime", "pixel art anime",

    // Character Types
    "anime girl", "anime boy", "anime couple", "anime group", "anime friends",
    "waifu", "husbando", "chibi", "kawaii", "moe",
    "bishoujo", "bishounen", "ikemen", "megane", "kemonomimi",
    "catgirl", "foxgirl", "wolfgirl", "bunny girl", "maid",
    "schoolgirl", "idol", "magical girl", "warrior", "samurai",
    "ninja", "witch", "vampire", "demon", "angel",
    "elf", "fairy", "mermaid", "goddess", "princess",

    // Emotions & Moods
    "anime happy", "anime sad", "anime crying", "anime smile", "anime laugh",
    "anime peaceful", "anime serene", "anime melancholy", "anime nostalgic", "anime lonely",
    "anime romantic", "anime love", "anime heartwarming", "anime wholesome", "anime cute",
    "anime cool", "anime epic", "anime badass", "anime intense", "anime dramatic",

    // Actions & Scenes
    "anime fighting", "anime battle", "anime action", "anime running", "anime flying",
    "anime walking", "anime sitting", "anime sleeping", "anime reading", "anime studying",
    "anime cooking", "anime eating", "anime drinking tea", "anime playing music", "anime singing",
    "anime dancing", "anime swimming", "anime cycling", "anime driving", "anime traveling",

    // Objects & Items
    "anime katana", "anime sword", "anime weapon", "anime magic", "anime spell",
    "anime book", "anime letter", "anime phone", "anime headphones", "anime umbrella",
    "anime flower", "anime rose", "anime butterfly", "anime lantern", "anime fireworks",

    // Weather & Atmosphere
    "anime rainy day", "anime stormy", "anime thunderstorm", "anime foggy", "anime misty",
    "anime sunny", "anime cloudy", "anime windy", "anime snowing", "anime blizzard",
    "anime rainbow", "anime aurora", "anime northern lights", "anime starry night", "anime moonlight",
    "anime golden hour", "anime blue hour", "anime twilight", "anime dusk", "anime dawn",

    // Genres
    "isekai", "slice of life", "romance anime", "comedy anime", "action anime",
    "adventure anime", "fantasy anime", "sci-fi anime", "mecha anime", "sports anime",
    "horror anime", "mystery anime", "thriller anime", "psychological anime", "seinen",
    "shounen", "shoujo", "josei", "ecchi", "harem",

    // Specific Visual Elements
    "anime eyes", "anime hair", "anime uniform", "anime kimono", "anime yukata",
    "anime dress", "anime costume", "anime armor", "anime wings", "anime halo",
    "anime tears", "anime blush", "anime sparkles", "anime petals", "anime feathers",

    // Time Periods
    "feudal japan anime", "edo period anime", "meiji era anime", "modern anime", "futuristic anime",
    "post apocalyptic anime", "steampunk anime", "cyberpunk anime", "medieval anime", "ancient anime",

    // Popular Characters (generic searches)
    "anime protagonist", "anime antagonist", "anime villain", "anime hero", "anime heroine",
    "anime side character", "anime mascot", "anime pet", "anime familiar", "anime spirit",

    // Music & Sound
    "anime concert", "anime band", "anime orchestra", "anime piano", "anime guitar",
    "anime violin", "anime drums", "anime dj", "vocaloid", "hatsune miku",

    // Food & Cuisine
    "anime food", "anime ramen", "anime sushi", "anime bento", "anime onigiri",
    "anime takoyaki", "anime dango", "anime pocky", "anime cake", "anime parfait",

    // Japanese Culture
    "anime festival", "anime matsuri", "anime hanami", "anime tanabata", "anime new year",
    "anime shrine visit", "anime torii", "anime temple gate", "anime zen garden", "anime hot spring",
    "anime onsen", "anime ryokan", "anime tatami", "anime futon", "anime kotatsu",

    // Transportation
    "anime bullet train", "anime shinkansen", "anime airplane", "anime ship", "anime boat",
    "anime motorcycle", "anime car", "anime bicycle", "anime scooter", "anime skateboard",

    // Technology
    "anime robot", "anime mecha", "anime gundam", "anime eva", "anime cyborg",
    "anime ai", "anime virtual reality", "anime hologram", "anime spaceship", "anime space station",

    // Nature Elements
    "anime garden", "anime park", "anime river", "anime waterfall", "anime lake",
    "anime pond", "anime bamboo forest", "anime maple", "anime pine", "anime wisteria",
    "anime sunflower", "anime lotus", "anime hydrangea", "anime cosmos flower", "anime lavender"
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

  // Signal emitted when discover generates a random query (so UI can update search box)
  signal discoveryQueryGenerated(string query)

  // -------------------------------------------------
  // Discover random wallpapers with random query and sorting
  // Returns the generated query
  function discover() {
    if (fetching) {
      return "";
    }

    // Generate random query
    var randomQuery = generateRandomQuery();

    // Store original sorting and set to random
    var originalSorting = sorting;
    sorting = "random";

    // Clear seed to get truly random results
    seed = "";

    Logger.d("Wallhaven", "Discovering with query:", randomQuery);

    // Emit signal so UI can update search box
    discoveryQueryGenerated(randomQuery);

    // Perform search with random query
    search(randomQuery, 1);

    // Restore original sorting after search starts (for UI display)
    // The actual search already captured the "random" sorting
    Qt.callLater(function() {
      sorting = originalSorting;
    });

    return randomQuery;
  }

  // -------------------------------------------------
  // Generate a random anime-specific search query
  function generateAnimeQuery() {
    // Pick 1-2 random anime words
    var numWords = Math.random() < 0.7 ? 1 : 2;
    var query = "";
    var usedIndices = [];

    for (var i = 0; i < numWords; i++) {
      var idx;
      do {
        idx = Math.floor(Math.random() * animeDiscoveryWords.length);
      } while (usedIndices.indexOf(idx) !== -1);

      usedIndices.push(idx);
      if (query !== "") query += " ";
      query += animeDiscoveryWords[idx];
    }

    return query;
  }

  // -------------------------------------------------
  // Discover random anime wallpapers
  // Returns the generated query
  function discoverAnime() {
    if (fetching) {
      return "";
    }

    // Generate random anime query
    var randomQuery = generateAnimeQuery();

    // Store original sorting and categories, set to anime-focused
    var originalSorting = sorting;
    var originalCategories = categories;
    sorting = "random";
    categories = "010"; // Only anime category

    // Clear seed to get truly random results
    seed = "";

    Logger.d("Wallhaven", "Discovering anime with query:", randomQuery);

    // Emit signal so UI can update search box
    discoveryQueryGenerated(randomQuery);

    // Perform search with random query
    search(randomQuery, 1);

    // Restore original settings after search starts
    Qt.callLater(function() {
      sorting = originalSorting;
      categories = originalCategories;
    });

    return randomQuery;
  }
}


