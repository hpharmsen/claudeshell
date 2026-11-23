import Foundation

/// Starts a program in a folder, optionally with text on its standard input, and returns its standard output.
public typealias ProcessRunner = @Sendable (_ program: String, _ arguments: [String], _ directory: URL,
                                            _ input: String?, _ timeout: TimeInterval) async throws -> String

/// Why a process gave no usable output.
public enum SubprocessError: Error, Equatable, Sendable {
    /// The program could not be started, for instance because it does not exist.
    case launchFailed(String)
    /// The program ended with an exit code other than zero, or by a signal; `output` is its standard output.
    case failed(exitCode: Int32, output: String)
    /// The program ran longer than the timeout and was terminated.
    case timedOut
}

/// Runs a program to its end without keeping a thread of the cooperative pool busy.
public enum Subprocess {
    /// Blocking reads and writes on the pipes happen here, never on the cooperative pool.
    private static let pipes = DispatchQueue(label: "Claudeshell.Subprocess", attributes: .concurrent)

    /// Runs a program with the environment of the app; this is the real `ProcessRunner`.
    public static func run(_ program: String, _ arguments: [String], _ directory: URL,
                           _ input: String?, _ timeout: TimeInterval) async throws -> String {
        try await run(program, arguments, directory, input, timeout, environment: nil)
    }

    /// Runs a program and returns its standard output; a nil environment inherits that of the app.
    /// Throws `SubprocessError`, or `CancellationError` when the task is cancelled, which also ends the process.
    public static func run(_ program: String, _ arguments: [String], _ directory: URL, _ input: String?,
                           _ timeout: TimeInterval, environment: [String: String]?) async throws -> String {
        let execution = Execution()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                execution.start(continuation, program: program, arguments: arguments, directory: directory,
                                input: input, timeout: timeout, environment: environment)
            }
        } onCancel: {
            execution.stop(CancellationError())
        }
    }

    /// One running process and the task that waits for it; the lock guards every stored property.
    private final class Execution: @unchecked Sendable {
        private let lock = NSLock()
        private let process = Process()
        private var continuation: CheckedContinuation<String, any Error>?
        private var timer: DispatchWorkItem?
        private var stopped: (any Error)?
        private var output = Data()

        /// Launches the process; the continuation resumes when it has ended and its output is read, or on `stop`.
        func start(_ continuation: CheckedContinuation<String, any Error>, program: String, arguments: [String],
                   directory: URL, input: String?, timeout: TimeInterval, environment: [String: String]?) {
            let stdin = Pipe(), stdout = Pipe(), stderr = Pipe()
            process.executableURL = URL(fileURLWithPath: program)
            process.arguments = arguments
            process.currentDirectoryURL = directory
            // Assigning nil would start the program with an empty environment instead of the inherited one.
            if let environment { process.environment = environment }
            process.standardInput = input == nil ? FileHandle.nullDevice : stdin
            process.standardOutput = stdout
            process.standardError = stderr

            // The process has ended and both pipes are read to their end when the group is empty.
            let done = DispatchGroup()
            done.enter()
            process.terminationHandler = { _ in done.leave() }

            let failure: (any Error)? = lock.withLock {
                if let stopped { return stopped }
                do { try process.run() } catch { return SubprocessError.launchFailed(error.localizedDescription) }
                self.continuation = continuation
                let timer = DispatchWorkItem { self.stop(SubprocessError.timedOut) }
                self.timer = timer
                Subprocess.pipes.asyncAfter(deadline: .now() + timeout, execute: timer)
                return nil
            }
            if let failure { return continuation.resume(throwing: failure) }

            // Both streams are drained while the input is written, so no side waits on a full pipe.
            for (handle, keep) in [(stdout.fileHandleForReading, true), (stderr.fileHandleForReading, false)] {
                done.enter()
                Subprocess.pipes.async {
                    let data = (try? handle.readToEnd()) ?? Data()
                    if keep { self.lock.withLock { self.output = data } }
                    done.leave()
                }
            }
            if let input {
                let handle = stdin.fileHandleForWriting
                Subprocess.pipes.async {
                    // A program that ends without reading its input must give an error here, not a SIGPIPE in the app.
                    _ = fcntl(handle.fileDescriptor, F_SETNOSIGPIPE, 1)
                    try? handle.write(contentsOf: Data(input.utf8))
                    try? handle.close()
                }
            }
            done.notify(queue: Subprocess.pipes) {
                let output = String(decoding: self.lock.withLock { self.output }, as: UTF8.self)
                let succeeded = self.process.terminationReason == .exit && self.process.terminationStatus == 0
                self.finish(succeeded ? .success(output)
                                      : .failure(SubprocessError.failed(exitCode: self.process.terminationStatus, output: output)))
            }
        }

        /// Terminates the process and lets the waiting task throw; before the launch it prevents the launch.
        func stop(_ error: any Error) {
            lock.withLock {
                stopped = error
                if process.isRunning { process.terminate() }
            }
            finish(.failure(error))
        }

        /// Resumes the waiting task once; later calls do nothing.
        private func finish(_ result: Result<String, any Error>) {
            let (waiting, timer) = lock.withLock {
                defer { (continuation, self.timer) = (nil, nil) }
                return (continuation, self.timer)
            }
            timer?.cancel()
            waiting?.resume(with: result)
        }
    }
}
