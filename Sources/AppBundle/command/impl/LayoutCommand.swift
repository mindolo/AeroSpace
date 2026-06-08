import AppKit
import Common

struct LayoutCommand: Command {
    let args: LayoutCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        let window = target.windowOrNil

        // Toggle resolution: .bsp uses workspace state; all others use window state
        let targetDescription = args.toggleBetween.val.first(where: { desc in
            desc == .bsp
                ? !target.workspace.bspEnabled
                : !(window?.matchesDescription(desc) ?? false)
        }) ?? args.toggleBetween.val.first.orDie()

        // Already in target state?
        let alreadyMatches = targetDescription == .bsp
            ? target.workspace.bspEnabled
            : (window?.matchesDescription(targetDescription) ?? false)
        if alreadyMatches { return .fail }

        // .bsp is workspace-level — no focused window required
        if targetDescription == .bsp {
            rebalanceBspWorkspace(target.workspace)
            return .succ
        }

        // Leaving BSP: flatten nested binary tree before applying new layout
        if target.workspace.bspEnabled {
            let root = target.workspace.rootTilingContainer
            for window in root.allLeafWindowsRecursive {
                window.bind(to: root, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
            }
            target.workspace.normalizeContainers()
            target.workspace.bspEnabled = false
        }

        guard let window else {
            return .fail(io.err(noWindowIsFocused))
        }
        switch targetDescription {
            case .h_accordion:
                return changeTilingLayout(io, targetLayout: .accordion, targetOrientation: .h, window: window)
            case .v_accordion:
                return changeTilingLayout(io, targetLayout: .accordion, targetOrientation: .v, window: window)
            case .h_tiles:
                return changeTilingLayout(io, targetLayout: .tiles, targetOrientation: .h, window: window)
            case .v_tiles:
                return changeTilingLayout(io, targetLayout: .tiles, targetOrientation: .v, window: window)
            case .accordion:
                return changeTilingLayout(io, targetLayout: .accordion, targetOrientation: nil, window: window)
            case .tiles:
                return changeTilingLayout(io, targetLayout: .tiles, targetOrientation: nil, window: window)
            case .horizontal:
                return changeTilingLayout(io, targetLayout: nil, targetOrientation: .h, window: window)
            case .vertical:
                return changeTilingLayout(io, targetLayout: nil, targetOrientation: .v, window: window)
            case .tiling:
                guard let parent = window.parent else { return .fail }
                switch parent.cases {
                    case .macosPopupWindowsContainer:
                        return .fail // Impossible
                    case .macosMinimizedWindowsContainer, .macosFullscreenWindowsContainer, .macosHiddenAppsWindowsContainer:
                        return .fail(io.err("Can't change layout for macOS minimized, fullscreen windows or windows or hidden apps. This behavior is subject to change"))
                    case .tilingContainer:
                        return .succ // Nothing to do
                    case .workspace(let workspace):
                        window.lastFloatingSize = try await window.getAxSize() ?? window.lastFloatingSize
                        try await window.relayoutWindow(on: workspace, forceTile: true)
                        return .succ
                }
            case .bsp:
                return .fail // unreachable — handled above
            case .floating:
                let workspace = target.workspace
                window.bindAsFloatingWindow(to: workspace)
                if let size = window.lastFloatingSize { window.setAxFrame(nil, size) }
                return .succ
        }
    }
}

@MainActor private func changeTilingLayout(_ io: CmdIo, targetLayout: Layout?, targetOrientation: Orientation?, window: Window) -> BinaryExitCode {
    guard let parent = window.parent else { return .fail }
    switch parent.cases {
        case .tilingContainer(let parent):
            window.nodeWorkspace?.bspEnabled = false
            let targetOrientation = targetOrientation ?? parent.orientation
            let targetLayout = targetLayout ?? parent.layout
            parent.layout = targetLayout
            parent.changeOrientation(targetOrientation)
            return .succ
        case .workspace, .macosMinimizedWindowsContainer, .macosFullscreenWindowsContainer,
             .macosPopupWindowsContainer, .macosHiddenAppsWindowsContainer:
            return .fail(io.err("The window is non-tiling"))
    }
}

extension Window {
    fileprivate func matchesDescription(_ layout: LayoutCmdArgs.LayoutDescription) -> Bool {
        return switch layout {
            case .accordion:   (parent as? TilingContainer)?.layout == .accordion
            case .tiles:       (parent as? TilingContainer)?.layout == .tiles && nodeWorkspace?.bspEnabled != true
            case .horizontal:  (parent as? TilingContainer)?.orientation == .h
            case .vertical:    (parent as? TilingContainer)?.orientation == .v
            case .h_accordion: (parent as? TilingContainer).map { $0.layout == .accordion && $0.orientation == .h } == true
            case .v_accordion: (parent as? TilingContainer).map { $0.layout == .accordion && $0.orientation == .v } == true
            case .h_tiles:     (parent as? TilingContainer).map { $0.layout == .tiles && $0.orientation == .h } == true && nodeWorkspace?.bspEnabled != true
            case .v_tiles:     (parent as? TilingContainer).map { $0.layout == .tiles && $0.orientation == .v } == true && nodeWorkspace?.bspEnabled != true
            case .tiling:      parent is TilingContainer
            case .floating:    parent is Workspace
            case .bsp:         nodeWorkspace?.bspEnabled == true
        }
    }
}
