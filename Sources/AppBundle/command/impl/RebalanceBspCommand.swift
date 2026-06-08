import AppKit
import Common

struct RebalanceBspCommand: Command {
    let args: RebalanceBspCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache: Bool = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        guard !target.workspace.rootTilingContainer.allLeafWindowsRecursive.isEmpty else { return .succ }
        rebalanceBspWorkspace(target.workspace)
        return .succ
    }
}
