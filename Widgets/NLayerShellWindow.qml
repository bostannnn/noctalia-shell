import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

PanelWindow {
  id: root

  property string layerNamespace: ""
  property int layerShellLayer: WlrLayer.Top
  property int layerShellExclusionMode: ExclusionMode.Ignore
  property int layerShellKeyboardFocus: WlrKeyboardFocus.None

  color: Color.transparent

  WlrLayershell.namespace: layerNamespace
  WlrLayershell.layer: layerShellLayer
  WlrLayershell.keyboardFocus: layerShellKeyboardFocus
  WlrLayershell.exclusionMode: layerShellExclusionMode
}

