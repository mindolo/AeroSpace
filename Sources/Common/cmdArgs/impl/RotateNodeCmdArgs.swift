public struct RotateNodeCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .rotateNode,
        allowInConfig: true,
        help: rotate_node_help_generated,
        flags: [
            "--workspace": workspaceSubArgParser(),
            "--recursive": trueBoolFlag(\.recursive),
        ],
        posArgs: [],
    )

    public var recursive: Bool = false
}
