// Shared JS library for simple file existence checks
.pragma library

// Minimal synchronous file existence helper using XMLHttpRequest GET request
// Note: Uses GET instead of HEAD because QML's XHR handles it more reliably for file://
function fileExists(path, parent) {
  if (!path)
    return false;

  try {
    var xhr = new XMLHttpRequest();
    // Use synchronous GET request with small read to check file existence
    // The async=false parameter makes this synchronous
    xhr.open("GET", "file://" + path, false);
    xhr.send(null);
    // For file:// protocol: status 0 with non-empty response means success
    // status 200 also indicates success
    if (xhr.status === 200) {
      return true;
    }
    if (xhr.status === 0) {
      // For local files, status 0 can mean success or failure
      // Check if we got any content
      return xhr.responseText !== null && xhr.responseText.length > 0;
    }
    return false;
  } catch (e) {
    // Exception means file doesn't exist or can't be read
    return false;
  }
}
