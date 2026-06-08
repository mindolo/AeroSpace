import Common

private let bspRowGroupingThreshold: Double = 50

@MainActor func reverseContainerChildren(_ container: TilingContainer) {
    let snapshot = container.children.map { child in (child, child.unbindFromParent().adaptiveWeight) }
    for (child, weight) in snapshot.reversed() {
        child.bind(to: container, adaptiveWeight: weight, index: INDEX_BIND_LAST)
    }
}

@MainActor func rotateContainer(_ container: TilingContainer) {
    reverseContainerChildren(container)
    container.changeOrientation(container.orientation.opposite)
}

@MainActor func rotateSubtree(_ container: TilingContainer) {
    for child in container.children {
        if let c = child as? TilingContainer { rotateSubtree(c) }
    }
    rotateContainer(container)
}

@MainActor func flipSubtree(_ container: TilingContainer) {
    reverseContainerChildren(container)
    for child in container.children {
        if let c = child as? TilingContainer { flipSubtree(c) }
    }
}

@MainActor func rebalanceBspWorkspace(_ workspace: Workspace) {
    let root = workspace.rootTilingContainer
    let windowsWithRects = root.allLeafWindowsRecursive.map { ($0, $0.lastAppliedLayoutPhysicalRect) }
    guard windowsWithRects.count > 1 else {
        workspace.bspEnabled = true
        return
    }
    let sorted = windowsWithRects.sorted { a, b in
        guard let ra = a.1 else { return b.1 != nil }
        guard let rb = b.1 else { return false }
        if abs(ra.center.y - rb.center.y) > bspRowGroupingThreshold { return ra.center.y < rb.center.y }
        return ra.center.x < rb.center.x
    }
    for (window, _) in sorted {
        window.bind(to: root, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
    }
    workspace.normalizeContainers()
    workspace.bspEnabled = true
    buildBspSubtree(windows: sorted.map(\.0), rect: workspace.workspaceMonitor.visibleRectPaddedByOuterGaps, parent: root, index: 0)
}

@MainActor func buildBspSubtree(windows: [Window], rect: Rect, parent: TilingContainer, index: Int) {
    guard !windows.isEmpty else { return }
    if windows.count == 1 {
        windows[0].bind(to: parent, adaptiveWeight: WEIGHT_AUTO, index: index)
        return
    }
    let orientation: Orientation = rect.width >= rect.height ? .h : .v
    let container = TilingContainer(parent: parent, adaptiveWeight: WEIGHT_AUTO, orientation, .tiles, index: index)
    let mid = windows.count / 2
    if orientation == .h {
        let half = rect.width / 2
        buildBspSubtree(
            windows: Array(windows[..<mid]),
            rect: Rect(topLeftX: rect.topLeftX, topLeftY: rect.topLeftY, width: half, height: rect.height),
            parent: container, index: 0)
        buildBspSubtree(
            windows: Array(windows[mid...]),
            rect: Rect(topLeftX: rect.topLeftX + half, topLeftY: rect.topLeftY, width: half, height: rect.height),
            parent: container, index: INDEX_BIND_LAST)
    } else {
        let half = rect.height / 2
        buildBspSubtree(
            windows: Array(windows[..<mid]),
            rect: Rect(topLeftX: rect.topLeftX, topLeftY: rect.topLeftY, width: rect.width, height: half),
            parent: container, index: 0)
        buildBspSubtree(
            windows: Array(windows[mid...]),
            rect: Rect(topLeftX: rect.topLeftX, topLeftY: rect.topLeftY + half, width: rect.width, height: half),
            parent: container, index: INDEX_BIND_LAST)
    }
}
