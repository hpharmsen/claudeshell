import Foundation
import Testing
@testable import ClaudeshellCore

// MARK: - Helpers

private let tmp = URL(fileURLWithPath: "/tmp")

/// The seconds an async call takes, with its outcome.
private func timed<T: Sendable>(_ work: () async throws -> T) async -> (seconds: TimeInterval, result: Result<T, any Error>) {
    let start = Date()
    do {
        let value = try await work()
        return (Date().timeIntervalSince(start), .success(value))
    } catch {
        return (Date().timeIntervalSince(start), .failure(error))
    }
}

/// The error of a failed outcome, nil when it succeeded.
private func failure<T>(_ result: Result<T, any Error>) -> (any Error)? {
    if case .failure(let error) = result { return error }
    return nil
}

/// Waits until a condition holds, at most `seconds`, and returns whether it did.
private func waitUntil(_ seconds: TimeInterval = 3, _ condition: () -> Bool) async throws -> Bool {
    let deadline = Date().addingTimeInterval(seconds)
    while !condition() {
        if Date() > deadline { return false }
        try await Task.sleep(for: .milliseconds(20))
    }
    return true
}

/// Whether a process with this id still exists.
private func isAlive(_ pid: Int32) -> Bool { kill(pid, 0) == 0 }

// MARK: - Output

@Test func runReturnsStandardOutput() async throws {
    #expect(try await Subprocess.run("/bin/echo", ["hallo"], tmp, nil, 5) == "hallo\n")
}

@Test func runMatchesTheInjectedFunctionType() async throws {
    let run: ProcessRunner = Subprocess.run
    #expect(try await run("/bin/echo", ["hallo"], tmp, nil, 5) == "hallo\n")
}

@Test func runWithoutOutputReturnsEmptyText() async throws {
    #expect(try await Subprocess.run("/usr/bin/true", [], tmp, nil, 5) == "")
}

@Test func runUsesTheDirectory() async throws {
    let dir = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let output = try await Subprocess.run("/bin/pwd", [], dir, nil, 5)
    let printed = URL(fileURLWithPath: output.trimmingCharacters(in: .newlines))
    #expect(printed.resolvingSymlinksInPath().path == dir.resolvingSymlinksInPath().path)
}

@Test func standardErrorIsNotPartOfTheOutput() async throws {
    #expect(try await Subprocess.run("/bin/sh", ["-c", "echo fout >&2; echo goed"], tmp, nil, 5) == "goed\n")
}

// MARK: - Input

@Test func largeInputComesBackComplete() async throws {
    let input = String(repeating: "0123456789abcdef", count: 12_800)
    #expect(input.utf8.count == 204_800)
    #expect(try await Subprocess.run("/bin/cat", [], tmp, input, 10) == input)
}

@Test func largeOutputOnBothStreamsDoesNotDeadlock() async throws {
    let script = "head -c 300000 /dev/zero | tr '\\0' 'e' >&2; head -c 300000 /dev/zero | tr '\\0' 'o'"
    #expect(try await Subprocess.run("/bin/sh", ["-c", script], tmp, nil, 10).count == 300_000)
}

@Test func withoutInputTheProgramReadsEndOfFile() async throws {
    #expect(try await Subprocess.run("/bin/cat", [], tmp, nil, 5) == "")
}

@Test func emptyInputGivesEmptyOutput() async throws {
    #expect(try await Subprocess.run("/bin/cat", [], tmp, "", 5) == "")
}

@Test func aProgramThatDoesNotReadItsInputDoesNotCrashTheCaller() async throws {
    let input = String(repeating: "x", count: 200_000)
    #expect(try await Subprocess.run("/bin/echo", ["klaar"], tmp, input, 5) == "klaar\n")
}

// MARK: - Environment

@Test func nilEnvironmentInheritsTheEnvironmentOfTheApp() async throws {
    let output = try await Subprocess.run("/usr/bin/env", [], tmp, nil, 5, environment: nil)
    #expect(output.contains("PATH="))
}

@Test func aGivenEnvironmentReplacesTheInheritedOne() async throws {
    let output = try await Subprocess.run("/usr/bin/env", [], tmp, nil, 5, environment: ["HOME": "/tmp", "USER": "gebruiker"])
    #expect(Set(output.split(separator: "\n").map(String.init)) == ["HOME=/tmp", "USER=gebruiker"])
}

// MARK: - Errors

@Test func aNonZeroExitCodeThrowsWithCodeAndOutput() async {
    let outcome = await timed { try await Subprocess.run("/bin/sh", ["-c", "echo '{\"is_error\":true}'; exit 1"], tmp, nil, 5) }
    #expect(failure(outcome.result) as? SubprocessError == .failed(exitCode: 1, output: "{\"is_error\":true}\n"))
}

@Test func theExitCodeIsCarriedAsIs() async {
    let outcome = await timed { try await Subprocess.run("/bin/sh", ["-c", "exit 42"], tmp, nil, 5) }
    #expect(failure(outcome.result) as? SubprocessError == .failed(exitCode: 42, output: ""))
}

@Test func aProgramThatDoesNotExistThrows() async {
    let outcome = await timed { try await Subprocess.run("/bestaat/niet", [], tmp, nil, 5) }
    guard case .launchFailed = failure(outcome.result) as? SubprocessError else {
        Issue.record("expected launchFailed, got \(outcome.result)")
        return
    }
}

@Test func aDirectoryThatDoesNotExistThrows() async {
    let outcome = await timed { try await Subprocess.run("/bin/pwd", [], URL(fileURLWithPath: "/bestaat/niet"), nil, 5) }
    #expect(failure(outcome.result) is SubprocessError)
}

// MARK: - Timeout and cancellation

@Test func aTimeoutThrowsWithinASecondAndEndsTheProcess() async throws {
    let dir = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let outcome = await timed { try await Subprocess.run("/bin/sh", ["-c", "echo $$ > pid; exec /bin/sleep 5"], dir, nil, 0.5) }
    #expect(failure(outcome.result) as? SubprocessError == .timedOut)
    #expect(outcome.seconds >= 0.4 && outcome.seconds < 1)
    let pid = try #require(Int32(try String(contentsOf: dir.appendingPathComponent("pid"), encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)))
    #expect(try await waitUntil { !isAlive(pid) })
}

@Test func cancellingTheTaskEndsTheCallAndTheProcess() async throws {
    let dir = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let pidFile = dir.appendingPathComponent("pid")
    let task = Task { await timed { try await Subprocess.run("/bin/sh", ["-c", "echo $$ > pid; exec /bin/sleep 5"], dir, nil, 30) } }
    #expect(try await waitUntil { ((try? String(contentsOf: pidFile, encoding: .utf8)) ?? "").hasSuffix("\n") })
    let pid = try #require(Int32(try String(contentsOf: pidFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)))
    #expect(isAlive(pid))

    let cancelledAt = Date()
    task.cancel()
    let outcome = await task.value
    #expect(Date().timeIntervalSince(cancelledAt) < 1)
    #expect(failure(outcome.result) is CancellationError)
    #expect(try await waitUntil { !isAlive(pid) })
}

@Test func aTaskCancelledBeforeTheCallStartsNoProcess() async throws {
    let dir = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return await timed { try await Subprocess.run("/usr/bin/touch", ["gestart"], dir, nil, 5) }
    }
    let outcome = await task.value
    #expect(failure(outcome.result) is CancellationError)
    #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent("gestart").path))
}

@Test func manyCallsAtOnceAllFinish() async throws {
    let outputs = try await withThrowingTaskGroup(of: String.self) { group in
        for index in 0..<40 { group.addTask { try await Subprocess.run("/bin/sh", ["-c", "sleep 0.2; echo \(index)"], tmp, nil, 10) } }
        return try await group.reduce(into: [String]()) { $0.append($1) }
    }
    #expect(Set(outputs) == Set((0..<40).map { "\($0)\n" }))
}
