pragma Singleton

import QtQuick

QtObject {
  id: root

  // Map of version number to migration component
  readonly property var migrations: ({
                                       26: migration26Component,
                                       27: migration27Component
                                     })

  // Migration components
  property Component migration26Component: Migration26 {}
  property Component migration27Component: Migration27 {}
}
