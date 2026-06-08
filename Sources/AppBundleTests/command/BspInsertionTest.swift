@testable import AppBundle
import Common
import XCTest

@MainActor
final class BspInsertionTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testBspEmptyWorkspaceFallsToRoot() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        workspace.bspEnabled = true

        let windowA = TestWindow.new(id: 1, parent: root)
        try await windowA.relayoutWindow(on: workspace, forceTile: true)

        assertEquals(root.layoutDescription, .h_tiles([.window(1)]))
    }

    func testBspWideSplitsHorizontally() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        workspace.bspEnabled = true

        let windowA = TestWindow.new(id: 1, parent: root)
        assertEquals(windowA.focusWindow(), true)
        windowA.lastAppliedLayoutPhysicalRect = Rect(topLeftX: 0, topLeftY: 0, width: 200, height: 100)

        let windowB = TestWindow.new(id: 2, parent: root)
        try await windowB.relayoutWindow(on: workspace, forceTile: true)

        assertEquals(root.layoutDescription, .h_tiles([
            .h_tiles([.window(1), .window(2)]),
        ]))
    }

    func testBspTallSplitsVertically() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        workspace.bspEnabled = true

        let windowA = TestWindow.new(id: 1, parent: root)
        assertEquals(windowA.focusWindow(), true)
        windowA.lastAppliedLayoutPhysicalRect = Rect(topLeftX: 0, topLeftY: 0, width: 100, height: 200)

        let windowB = TestWindow.new(id: 2, parent: root)
        try await windowB.relayoutWindow(on: workspace, forceTile: true)

        assertEquals(root.layoutDescription, .h_tiles([
            .v_tiles([.window(1), .window(2)]),
        ]))
    }

    func testBspNilRectFallsToSiblingInsertion() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        workspace.bspEnabled = true

        let windowA = TestWindow.new(id: 1, parent: root)
        assertEquals(windowA.focusWindow(), true)
        // no lastAppliedLayoutPhysicalRect set — nil triggers fallthrough

        let windowB = TestWindow.new(id: 2, parent: root)
        try await windowB.relayoutWindow(on: workspace, forceTile: true)

        assertEquals(root.layoutDescription, .h_tiles([.window(1), .window(2)]))
    }

    func testBspDisabledUsesSiblingInsertion() async throws {
        let workspace = Workspace.get(byName: name)
        workspace.bspEnabled = false
        let root = workspace.rootTilingContainer

        let windowA = TestWindow.new(id: 1, parent: root)
        assertEquals(windowA.focusWindow(), true)
        windowA.lastAppliedLayoutPhysicalRect = Rect(topLeftX: 0, topLeftY: 0, width: 200, height: 100)

        let windowB = TestWindow.new(id: 2, parent: root)
        try await windowB.relayoutWindow(on: workspace, forceTile: true)

        assertEquals(root.layoutDescription, .h_tiles([.window(1), .window(2)]))
    }


    func testLayoutBspCommandEnablesBsp() async throws {
        let workspace = Workspace.get(byName: name)
        workspace.bspEnabled = false
        let root = workspace.rootTilingContainer
        let window = TestWindow.new(id: 1, parent: root)
        assertEquals(window.focusWindow(), true)

        try await LayoutCommand(args: LayoutCmdArgs(rawArgs: [], toggleBetween: [.bsp])).run(.defaultEnv, .emptyStdin)

        assertEquals(workspace.bspEnabled, true)
    }

    func testLayoutTilesCommandDisablesBsp() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        workspace.bspEnabled = true
        let window = TestWindow.new(id: 1, parent: root)
        assertEquals(window.focusWindow(), true)

        try await LayoutCommand(args: LayoutCmdArgs(rawArgs: [], toggleBetween: [.tiles])).run(.defaultEnv, .emptyStdin)

        assertEquals(workspace.bspEnabled, false)
    }

    func testLayoutTilesFromBspFlattensTree() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        workspace.bspEnabled = true
        // Simulate a BSP binary tree: root → container → [w1, w2], w3
        let container = TilingContainer(parent: root, adaptiveWeight: 1, .h, .tiles, index: INDEX_BIND_LAST)
        TestWindow.new(id: 1, parent: container)
        TestWindow.new(id: 2, parent: container)
        let window3 = TestWindow.new(id: 3, parent: root)
        assertEquals(window3.focusWindow(), true)

        try await LayoutCommand(args: LayoutCmdArgs(rawArgs: [], toggleBetween: [.tiles])).run(.defaultEnv, .emptyStdin)

        assertEquals(workspace.bspEnabled, false)
        assertEquals(root.layoutDescription, .h_tiles([.window(1), .window(2), .window(3)]))
    }

    func testRebalanceBspRebuildsBinaryTree() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        workspace.bspEnabled = true
        let w1 = TestWindow.new(id: 1, parent: root)
        let w2 = TestWindow.new(id: 2, parent: root)
        let w3 = TestWindow.new(id: 3, parent: root)
        assertEquals(w1.focusWindow(), true)
        w1.lastAppliedLayoutPhysicalRect = Rect(topLeftX: 0,   topLeftY: 0, width: 100, height: 100)
        w2.lastAppliedLayoutPhysicalRect = Rect(topLeftX: 100, topLeftY: 0, width: 100, height: 100)
        w3.lastAppliedLayoutPhysicalRect = Rect(topLeftX: 200, topLeftY: 0, width: 100, height: 100)

        try await RebalanceBspCommand(args: RebalanceBspCmdArgs(rawArgs: [])).run(.defaultEnv, .emptyStdin)

        assertEquals(workspace.bspEnabled, true)
        let currentRoot = workspace.rootTilingContainer
        assertEquals(currentRoot.allLeafWindowsRecursive.count, 3)
        assertEquals(currentRoot.children.allSatisfy { $0 is Window }, false)
    }

    func testBspPreselEastOpensRight() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        workspace.bspEnabled = true
        let w1 = TestWindow.new(id: 1, parent: root)
        assertEquals(w1.focusWindow(), true)
        workspace.bspPresel = .right

        let w2 = TestWindow.new(id: 2, parent: root)
        try await w2.relayoutWindow(on: workspace, forceTile: true)

        // w1 left, w2 right; presel consumed
        assertEquals(root.layoutDescription, .h_tiles([.h_tiles([.window(1), .window(2)])]))
        assertEquals(workspace.bspPresel, nil)
    }

    func testBspPreselNorthOpensAbove() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        workspace.bspEnabled = true
        let w1 = TestWindow.new(id: 1, parent: root)
        assertEquals(w1.focusWindow(), true)
        workspace.bspPresel = .up

        let w2 = TestWindow.new(id: 2, parent: root)
        try await w2.relayoutWindow(on: workspace, forceTile: true)

        // w2 above w1
        assertEquals(root.layoutDescription, .h_tiles([.v_tiles([.window(2), .window(1)])]))
        assertEquals(workspace.bspPresel, nil)
    }

    func testBspPreselCancelNoEffect() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        workspace.bspEnabled = true
        let w1 = TestWindow.new(id: 1, parent: root)
        assertEquals(w1.focusWindow(), true)
        workspace.bspPresel = .right

        try await BspPreselCommand(args: BspPreselCmdArgs(rawArgs: [], direction: nil)).run(.defaultEnv, .emptyStdin)

        assertEquals(workspace.bspPresel, nil)
    }

    func testBspPreselWorksWithoutRect() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        workspace.bspEnabled = true
        let w1 = TestWindow.new(id: 1, parent: root)
        assertEquals(w1.focusWindow(), true)
        // No lastAppliedLayoutPhysicalRect, but presel overrides
        workspace.bspPresel = .down

        let w2 = TestWindow.new(id: 2, parent: root)
        try await w2.relayoutWindow(on: workspace, forceTile: true)

        assertEquals(root.layoutDescription, .h_tiles([.v_tiles([.window(1), .window(2)])]))
    }

    func testRotateNodeFlipsOrientationAndReverses() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        workspace.bspEnabled = true
        let container = TilingContainer(parent: root, adaptiveWeight: 1, .h, .tiles, index: INDEX_BIND_LAST)
        let w1 = TestWindow.new(id: 1, parent: container)
        TestWindow.new(id: 2, parent: container)
        assertEquals(w1.focusWindow(), true)

        try await RotateNodeCommand(args: RotateNodeCmdArgs(rawArgs: [])).run(.defaultEnv, .emptyStdin)

        // orientation h→v, children reversed: [w2, w1]
        assertEquals(root.layoutDescription, .h_tiles([.v_tiles([.window(2), .window(1)])]))
    }

    func testRotateNodeFourTimesRestoresOriginal() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        workspace.bspEnabled = true
        let container = TilingContainer(parent: root, adaptiveWeight: 1, .h, .tiles, index: INDEX_BIND_LAST)
        let w1 = TestWindow.new(id: 1, parent: container)
        TestWindow.new(id: 2, parent: container)
        TestWindow.new(id: 3, parent: container)
        assertEquals(w1.focusWindow(), true)
        let original = root.layoutDescription

        for _ in 0 ..< 4 {
            try await RotateNodeCommand(args: RotateNodeCmdArgs(rawArgs: [])).run(.defaultEnv, .emptyStdin)
        }

        assertEquals(root.layoutDescription, original)
    }

    func testFlipNodeReversesChildren() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        workspace.bspEnabled = true
        let container = TilingContainer(parent: root, adaptiveWeight: 1, .h, .tiles, index: INDEX_BIND_LAST)
        let w1 = TestWindow.new(id: 1, parent: container)
        TestWindow.new(id: 2, parent: container)
        TestWindow.new(id: 3, parent: container)
        assertEquals(w1.focusWindow(), true)

        try await FlipNodeCommand(args: FlipNodeCmdArgs(rawArgs: [])).run(.defaultEnv, .emptyStdin)

        // orientation unchanged (h), children reversed: [w3, w2, w1]
        assertEquals(root.layoutDescription, .h_tiles([.h_tiles([.window(3), .window(2), .window(1)])]))
    }

    func testFlipNodeTwiceRestoresOriginal() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        workspace.bspEnabled = true
        let container = TilingContainer(parent: root, adaptiveWeight: 1, .h, .tiles, index: INDEX_BIND_LAST)
        let w1 = TestWindow.new(id: 1, parent: container)
        TestWindow.new(id: 2, parent: container)
        assertEquals(w1.focusWindow(), true)
        let original = root.layoutDescription

        try await FlipNodeCommand(args: FlipNodeCmdArgs(rawArgs: [])).run(.defaultEnv, .emptyStdin)
        try await FlipNodeCommand(args: FlipNodeCmdArgs(rawArgs: [])).run(.defaultEnv, .emptyStdin)

        assertEquals(root.layoutDescription, original)
    }

    func testSwapBspSubtreeDirectional() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        workspace.bspEnabled = true
        // BSP tree: root[left[w1, w2], right[w3]]
        let left = TilingContainer(parent: root, adaptiveWeight: 1, .v, .tiles, index: INDEX_BIND_LAST)
        let w1 = TestWindow.new(id: 1, parent: left)
        TestWindow.new(id: 2, parent: left)
        let right = TilingContainer(parent: root, adaptiveWeight: 1, .v, .tiles, index: INDEX_BIND_LAST)
        TestWindow.new(id: 3, parent: right)
        assertEquals(w1.focusWindow(), true)

        // adjacentNode = right (TilingContainer) → BSP subtree swap: left and right exchange positions
        try await SwapCommand(args: SwapCmdArgs(rawArgs: [], target: .direction(.right))).run(.defaultEnv, .emptyStdin)

        assertEquals(root.layoutDescription, .h_tiles([.v_tiles([.window(3)]), .v_tiles([.window(1), .window(2)])]))
    }
}
