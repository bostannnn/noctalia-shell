// Shared JS library for simple file existence checks
.pragma library

// Minimal file existence helper using FolderListModel to avoid spawning processes
function fileExists(path, parent) {
  if (!path)
    return false;

  // Split path into dir and filename
  const idx = path.lastIndexOf("/");
  const dir = idx >= 0 ? path.substring(0, idx) : ".";
  const name = idx >= 0 ? path.substring(idx + 1) : path;
  if (!name)
    return false;

  try {
    const folderUrl = "file://" + dir.replace(/"/g, '\\"');
    const filter = name.replace(/"/g, '\\"');
    const obj = Qt.createQmlObject(
      'import Qt.labs.folderlistmodel 2.15; FolderListModel { folder: "' + folderUrl + '"; showDirs: false; nameFilters: ["' + filter + '"]; }',
      parent || Qt.application,
      "FileExistsChecker"
    );
    const exists = obj.count > 0;
    obj.destroy();
    return exists;
  } catch (e) {
    return false;
  }
}
