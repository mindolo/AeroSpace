import AppKit
import Common

struct BspPreselCommand: Command {
    let args: BspPreselCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        target.workspace.bspPresel = args.direction.val
        return .succ
    }
}
