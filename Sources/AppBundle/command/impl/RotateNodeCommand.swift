import AppKit
import Common

struct RotateNodeCommand: Command {
    let args: RotateNodeCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        guard let window = target.windowOrNil else { return .fail(io.err(noWindowIsFocused)) }
        guard let parent = window.parent as? TilingContainer else { return .fail }
        if args.recursive {
            rotateSubtree(parent)
        } else {
            rotateContainer(parent)
        }
        return .succ
    }
}
