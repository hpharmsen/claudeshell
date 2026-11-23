import Foundation
import Testing
@testable import ClaudeshellCore

/// Builds a project folder with the given `runlocal.sh` and `.env` and returns the guessed localhost link.
private func guessedURL(script: String?, env: String? = nil) throws -> String? {
    let root = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: root) }
    try script?.write(to: root.appendingPathComponent("runlocal.sh"), atomically: true, encoding: .utf8)
    try env?.write(to: root.appendingPathComponent(".env"), atomically: true, encoding: .utf8)
    return LocalhostGuesser.url(for: root.path)?.absoluteString
}

// MARK: - A number in the script

@Test func runserverWithNumberYieldsThatPort() throws {
    #expect(try guessedURL(script: "#!/bin/bash\npython manage.py runserver 8082\n") == "http://localhost:8082")
}

@Test func httpServerWithNumberYieldsThatPort() throws {
    #expect(try guessedURL(script: "python -m http.server 8000\n") == "http://localhost:8000")
}

@Test func portOptionWithNumberYieldsThatPort() throws {
    #expect(try guessedURL(script: "uvicorn app:app --reload --port 8010\n") == "http://localhost:8010")
}

@Test func echoedLocalhostAddressYieldsItsPortWithoutPath() throws {
    #expect(try guessedURL(script: "echo 'http://localhost:8000/pad/'\nnpm start\n") == "http://localhost:8000")
}

@Test func loopbackAddressYieldsItsPort() throws {
    #expect(try guessedURL(script: "open http://127.0.0.1:4000\n") == "http://localhost:4000")
}

@Test func commentedLineIsIgnored() throws {
    let script = "# DATABASE_URL=postgres://gebruiker@localhost:5432/db\n  # runserver 7000\npython manage.py runserver 8080\n"
    #expect(try guessedURL(script: script) == "http://localhost:8080")
}

@Test func serverCommandWinsFromAnEarlierLocalhostAddress() throws {
    let script = "echo 'http://localhost:3000'\npython manage.py runserver 8080\n"
    #expect(try guessedURL(script: script) == "http://localhost:8080")
}

@Test func scriptWithCarriageReturnsYieldsThePort() throws {
    #expect(try guessedURL(script: "#!/bin/bash\r\npython manage.py runserver 8082\r\n") == "http://localhost:8082")
}

// MARK: - A variable in the script

@Test func variableIsReadFromEnvFile() throws {
    #expect(try guessedURL(script: "python manage.py runserver $PORT\n", env: "PORT=9000\n") == "http://localhost:9000")
}

@Test func quotedVariableIsReadFromEnvFile() throws {
    #expect(try guessedURL(script: "python manage.py runserver \"$PORT\"\n", env: "PORT=8086\n") == "http://localhost:8086")
}

@Test func bracedVariableTakesExactlyThatVariableFromEnvFile() throws {
    let env = "EMAIL_PORT=587\nLOCAL_PORT=8091\nLOCAL_PORT_EXTRA=1\n"
    #expect(try guessedURL(script: "python manage.py runserver ${LOCAL_PORT}\n", env: env) == "http://localhost:8091")
}

@Test func defaultOfVariableCountsWithoutEnvFile() throws {
    #expect(try guessedURL(script: "uvicorn app:app --port ${PORT:-8000}\n") == "http://localhost:8000")
}

@Test func envFileWinsFromDefaultOfVariable() throws {
    #expect(try guessedURL(script: "uvicorn app:app --port ${PORT:-8000}\n", env: "PORT=8005\n") == "http://localhost:8005")
}

@Test func assignmentInScriptYieldsThePort() throws {
    let script = "FRONTEND_PORT=5173\ncd frontend\npython -m http.server $FRONTEND_PORT\n"
    #expect(try guessedURL(script: script) == "http://localhost:5173")
}

@Test func assignmentInScriptWinsFromEnvFile() throws {
    #expect(try guessedURL(script: "PORT=8001\nrunserver $PORT\n", env: "PORT=9000\n") == "http://localhost:8001")
}

@Test func assignmentWithoutNumberIsSkipped() throws {
    let script = "LOCAL_PORT=${ANDERS:-$LOCAL_PORT}\npython manage.py runserver $LOCAL_PORT\n"
    #expect(try guessedURL(script: script, env: "LOCAL_PORT=8083\n") == "http://localhost:8083")
}

@Test func variableWithoutEnvFileYieldsNothing() throws {
    #expect(try guessedURL(script: "python manage.py runserver $PORT\n") == nil)
}

@Test func variableMissingInEnvFileYieldsNothing() throws {
    #expect(try guessedURL(script: "python manage.py runserver $PORT\n", env: "EMAIL_PORT=587\n") == nil)
}

@Test func localhostAddressCountsWhenTheServerCommandHasNoPort() throws {
    let script = "python manage.py runserver $PORT\necho 'http://localhost:8000'\n"
    #expect(try guessedURL(script: script) == "http://localhost:8000")
}

// MARK: - The line in .env

@Test func quotedValueInEnvFileCounts() throws {
    #expect(try guessedURL(script: "runserver $PORT\n", env: "PORT=\"9000\"\n") == "http://localhost:9000")
}

@Test func valueWithCommentInEnvFileCounts() throws {
    #expect(try guessedURL(script: "runserver $PORT\n", env: "PORT=9000 # commentaar\n") == "http://localhost:9000")
}

@Test func exportedValueInEnvFileCounts() throws {
    #expect(try guessedURL(script: "runserver $PORT\n", env: "export PORT=9000\n") == "http://localhost:9000")
}

@Test func envFileWithCarriageReturnsCounts() throws {
    #expect(try guessedURL(script: "runserver $PORT\n", env: "DEBUG=1\r\nPORT=9000\r\n") == "http://localhost:9000")
}

@Test func valueThatIsNoNumberYieldsNothing() throws {
    #expect(try guessedURL(script: "runserver $PORT\n", env: "PORT=abc\n") == nil)
    #expect(try guessedURL(script: "runserver $PORT\n", env: "PORT=9000abc\n") == nil)
}

@Test func commentedLineInEnvFileIsIgnored() throws {
    #expect(try guessedURL(script: "runserver $PORT\n", env: "# PORT=9000\n") == nil)
}

// MARK: - No port

@Test func scriptWithoutPortYieldsNothing() throws {
    #expect(try guessedURL(script: "swift build\nopen build/Voorbeeld.app\n") == nil)
}

@Test func emptyScriptYieldsNothing() throws {
    #expect(try guessedURL(script: "") == nil)
}

@Test func folderWithoutScriptYieldsNothing() throws {
    #expect(try guessedURL(script: nil, env: "PORT=9000\n") == nil)
}

@Test func portOutOfRangeYieldsNothing() throws {
    #expect(try guessedURL(script: "python manage.py runserver 0\n") == nil)
    #expect(try guessedURL(script: "python manage.py runserver 65536\n") == nil)
    #expect(try guessedURL(script: "python manage.py runserver 99999999999999999999999\n") == nil)
    #expect(try guessedURL(script: "python manage.py runserver 65535\n") == "http://localhost:65535")
}
