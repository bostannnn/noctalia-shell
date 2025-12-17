import QtQuick

/**
 * Migration v27:
 * 1. Migrate bar.floating to bar.mode
 * 2. Migrate settingsPanelAttachToBar to settingsPanelMode
 */
QtObject {
  id: root

  function migrate(adapter, logger, rawJson) {
    logger.i("Settings", "Running migration v27");

    try {
      // Migration 1: bar.floating → bar.mode
      var oldFloating = adapter.bar.floating ?? false;
      var oldScreenBorder = adapter.general.screenBorderEnabled ?? false;

      var newMode = "classic";
      if (oldScreenBorder) {
        newMode = "framed";
      } else if (oldFloating) {
        newMode = "floating";
      }

      adapter.bar.mode = newMode;
      logger.i("Settings", "  Migrated to bar.mode = '" + newMode + "'");

      // Migration 2: settingsPanelAttachToBar → settingsPanelMode
      if (rawJson?.ui?.settingsPanelAttachToBar !== undefined) {
        if (rawJson.ui.settingsPanelAttachToBar === true) {
          adapter.ui.settingsPanelMode = "attached";
        } else {
          adapter.ui.settingsPanelMode = "centered";
        }
        logger.i("Settings", "  Migrated settingsPanelAttachToBar to settingsPanelMode: " + adapter.ui.settingsPanelMode);
      }

      return true;
    } catch (e) {
      logger.e("Settings", "Migration v27 failed: " + e);
      return false;
    }
  }
}
