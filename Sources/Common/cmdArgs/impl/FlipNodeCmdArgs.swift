public struct FlipNodeCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .flipNode,
        allowInConfig: true,
        help: flip_node_help_generated,
        flags: [
            "--workspace": workspaceSubArgParser(),
            "--recursive": trueBoolFlag(\.recursive),
        ],
        posArgs: [],
    )

    public var recursive: Bool = false
}
