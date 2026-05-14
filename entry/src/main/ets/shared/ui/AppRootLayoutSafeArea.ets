export class AppRootLayoutSafeArea {
  static nonSafeAreaTypes(): Array<LayoutSafeAreaType> {
    return [LayoutSafeAreaType.SYSTEM];
  }

  static ignoredImmersiveEdges(): Array<LayoutSafeAreaEdge> {
    // Keep the entry root immersive at the status bar and landscape side cutouts; bottom remains system-managed.
    return [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.START, LayoutSafeAreaEdge.END];
  }
}
