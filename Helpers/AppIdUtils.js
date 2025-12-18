// Utility helpers for app IDs and pinned-app handling

function normalizeAppId(appId) {
  if (!appId || typeof appId !== "string")
    return "";
  return appId.toLowerCase().trim();
}

function resolveDesktopEntryId(appId) {
  if (!appId)
    return appId;

  // Try heuristic lookup first
  if (typeof DesktopEntries !== "undefined" && DesktopEntries.heuristicLookup) {
    try {
      const entry = DesktopEntries.heuristicLookup(appId);
      if (entry && entry.id) {
        return entry.id;
      }
    } catch (e) {}
  }

  // Then direct lookup
  if (typeof DesktopEntries !== "undefined" && DesktopEntries.byId) {
    try {
      const entry = DesktopEntries.byId(appId);
      if (entry && entry.id) {
        return entry.id;
      }
    } catch (e) {}
  }

  return appId;
}

function isPinned(appId, pinnedApps) {
  if (!appId || !pinnedApps || pinnedApps.length === 0)
    return false;
  const normalizedId = normalizeAppId(resolveDesktopEntryId(appId));
  return pinnedApps.some(pinnedId => normalizeAppId(pinnedId) === normalizedId);
}

function togglePinned(appId, pinnedApps) {
  if (!appId)
    return pinnedApps || [];

  const desktopEntryId = resolveDesktopEntryId(appId);
  const normalizedId = normalizeAppId(desktopEntryId);
  const next = (pinnedApps || []).slice();

  const existingIndex = next.findIndex(pinnedId => normalizeAppId(pinnedId) === normalizedId);
  if (existingIndex >= 0) {
    next.splice(existingIndex, 1);
  } else {
    next.push(desktopEntryId);
  }
  return next;
}

function getAppName(appId) {
  if (!appId)
    return appId;

  // Prefer heuristic lookup
  if (typeof DesktopEntries !== "undefined" && DesktopEntries.heuristicLookup) {
    try {
      const entry = DesktopEntries.heuristicLookup(appId);
      if (entry && entry.name) {
        return entry.name;
      }
    } catch (e) {}
  }

  if (typeof DesktopEntries !== "undefined" && DesktopEntries.byId) {
    try {
      const entry = DesktopEntries.byId(appId);
      if (entry && entry.name) {
        return entry.name;
      }
    } catch (e) {}
  }

  return appId;
}
