import Foundation

/// Runs the `aside-tweak` command, which does all the work on Aside's files.
struct Engine: Sendable {
    struct Status: Decodable, Sendable {
        struct Version: Decodable, Sendable {
            let version: String
            let tweaked: Bool
        }

        let versions: [Version]
        let autoApply: Bool
    }

    struct Failure: LocalizedError {
        let errorDescription: String?
    }

    let script: URL

    func status() async throws -> Status {
        try JSONDecoder().decode(Status.self, from: try await run("status", "--json"))
    }

    func apply() async throws { _ = try await run("apply") }
    func restore() async throws { _ = try await run("restore") }
    func setSidebarAnimation(_ choice: SidebarAnimation) async throws { _ = try await run("sidebar-animation", choice.rawValue) }
    func setAutoApply(_ isOn: Bool) async throws { _ = try await run("autoapply", isOn ? "on" : "off") }

    private func run(_ arguments: String...) async throws -> Data {
        let script = script
        return try await Task.detached {
            let process = Process()
            let output = Pipe()
            process.executableURL = script
            process.arguments = arguments
            process.standardOutput = output
            process.standardError = output
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                let message = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                throw Failure(errorDescription: message.isEmpty ? "aside-tweak failed." : message)
            }
            return data
        }.value
    }
}
