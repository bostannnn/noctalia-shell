import QtQuick

/**
 * Migration v27: Migrate bar.floating to bar.mode
 * 
 * Old settings:
 *   - bar.floating: true/false
 *   - general.screenBorderEnabled: true/false
 * 
 * New setting:
 *   - bar.mode: "classic" | "floating" | "framed"
 * 
 * Migration logic:
 *   - If screenBorderEnabled was true → mode = "framed"
 *   - Else if floating was true → mode = "floating"
 *   - Else → mode = "classic"
 */
QtObject {
  function migrate(adapter, Logger) {
    Logger.i("Migration", "Running migration v27: bar.floating → bar.mode");
    
    try {
      // Determine the new mode based on old settings
      var oldFloating = adapter.bar.floating ?? false;
      var oldScreenBorder = adapter.general.screenBorderEnabled ?? false;
      
      var newMode = "classic";
      if (oldScreenBorder) {
        newMode = "framed";
      } else if (oldFloating) {
        newMode = "floating";
      }
      
      // Set the new mode
      adapter.bar.mode = newMode;
      
      Logger.i("Migration", "  Migrated to bar.mode = '" + newMode + "' (was floating=" + oldFloating + ", screenBorderEnabled=" + oldScreenBorder + ")");
      
      return true;
    } catch (e) {
      Logger.e("Migration", "Migration v27 failed: " + e);
      return false;
    }
  }
}
