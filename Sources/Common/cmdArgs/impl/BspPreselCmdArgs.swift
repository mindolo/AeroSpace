public struct BspPreselCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .bspPresel,
        allowInConfig: true,
        help: bsp_presel_help_generated,
        flags: [
            "--workspace": workspaceSubArgParser(),
        ],
        posArgs: [newMandatoryPosArgParser(\.direction, parseBspPreselDirection, placeholder: "left|down|up|right|cancel")],
    )

    public var direction: Lateinit<CardinalDirection?> = .uninitialized

    public init(rawArgs: [String], direction: CardinalDirection?) {
        self.commonState = .init(rawArgs.slice)
        self.direction = .initialized(direction)
    }
}

func parseBspPreselCmdArgs(_ args: StrArrSlice) -> ParsedCmd<BspPreselCmdArgs> {
    parseSpecificCmdArgs(BspPreselCmdArgs(rawArgs: args), args)
}

private func parseBspPreselDirection(i: PosArgParserInput) -> ParsedCliArgs<CardinalDirection?> {
    if i.arg == "cancel" {
        return .init(.success(nil), advanceBy: 1)
    }
    return .init(parseEnum(i.arg, CardinalDirection.self).map(Optional.init), advanceBy: 1)
}
