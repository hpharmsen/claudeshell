import Foundation
import Testing
@testable import ClaudeshellCore

/// Builds a project folder with the given files (relative path to contents) and returns the guessed domains.
private func guessedDomains(folder: String = "janitor", files: [String: String] = [:]) throws -> [String] {
    let root = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: root) }
    let project = root.appendingPathComponent(folder)
    try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
    for (relativePath, contents) in files {
        let file = project.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.write(to: file, atomically: true, encoding: .utf8)
    }
    return DomainGuesser.domains(for: project.path)
}

private func settings(_ hosts: String) -> String {
    "DEBUG = False\nALLOWED_HOSTS = \(hosts)\nROOT_URLCONF = 'config.urls'\n"
}

// MARK: - Folder name

@Test func folderNamedLikeADomainYieldsThatDomain() throws {
    #expect(try guessedDomains(folder: "voorbeeld.nl") == ["voorbeeld.nl"])
}

@Test func plainFolderNameYieldsNoDomain() throws {
    #expect(try guessedDomains(folder: "janitor").isEmpty)
}

@Test func folderNamedLikeARejectedHostYieldsNothing() throws {
    #expect(try guessedDomains(folder: "gebruiker.github.io").isEmpty)
}

// MARK: - CNAME

@Test func cnameFileWithTrailingNewlineYieldsItsHost() throws {
    #expect(try guessedDomains(files: ["CNAME": "www.voorbeeld.nl\n"]) == ["www.voorbeeld.nl"])
}

// MARK: - package.json

@Test func packageJsonHomepageYieldsItsHost() throws {
    let json = "{\n  \"name\": \"app\",\n  \"homepage\": \"https://voorbeeld.nl/app\"\n}\n"
    #expect(try guessedDomains(files: ["package.json": json]) == ["voorbeeld.nl"])
}

@Test func brokenPackageJsonYieldsNoDomainAndNoError() throws {
    #expect(try guessedDomains(files: ["package.json": "{ \"homepage\": \"https://voorbeeld.nl"]).isEmpty)
}

@Test func brokenPackageJsonDoesNotBlockOtherSources() throws {
    let files = ["package.json": "{ not json", "CNAME": "www.voorbeeld.nl\n"]
    #expect(try guessedDomains(files: files) == ["www.voorbeeld.nl"])
}

// MARK: - pyproject.toml

@Test func pyprojectHomepageOnGithubYieldsNothing() throws {
    let toml = "[project]\nname = \"y\"\n\n[project.urls]\nHomepage = \"https://github.com/x/y\"\n"
    #expect(try guessedDomains(files: ["pyproject.toml": toml]).isEmpty)
}

@Test func pyprojectHomepageOnOwnDomainYieldsItsHost() throws {
    let toml = "[project]\nname = \"y\"\n\n[project.urls]\nHomepage = \"https://docs.voorbeeld.nl/start\"\n"
    #expect(try guessedDomains(files: ["pyproject.toml": toml]) == ["docs.voorbeeld.nl"])
}

// MARK: - settings.py

@Test func allowedHostsKeepsOnlyRealDomains() throws {
    let hosts = "['localhost', '127.0.0.1', 'app.voorbeeld.nl', '.herokuapp.com', '*']"
    #expect(try guessedDomains(files: ["config/settings.py": settings(hosts)]) == ["app.voorbeeld.nl"])
}

@Test func allowedHostsSpreadOverSeveralLinesIsRead() throws {
    let hosts = "[\n    'app.voorbeeld.nl',\n    \"www.voorbeeld.nl\",  # public site\n    'localhost',\n]"
    #expect(try guessedDomains(files: ["config/settings.py": settings(hosts)]) == ["app.voorbeeld.nl", "www.voorbeeld.nl"])
}

@Test func settingsInTheProjectRootIsFound() throws {
    #expect(try guessedDomains(files: ["settings.py": settings("['app.voorbeeld.nl']")]) == ["app.voorbeeld.nl"])
}

@Test func settingsTwoFoldersDeepIsFound() throws {
    #expect(try guessedDomains(files: ["src/app/settings.py": settings("['app.voorbeeld.nl']")]) == ["app.voorbeeld.nl"])
}

@Test func settingsFarBeyondThreeFoldersDeepIsIgnored() throws {
    #expect(try guessedDomains(files: ["a/b/c/d/e/settings.py": settings("['app.voorbeeld.nl']")]).isEmpty)
}

// MARK: - Rejected hosts (KTD9)

@Test func rejectedHostsInAllowedHostsYieldNothing() throws {
    let hosts = """
    ['intranet', '10.0.0.12', '*.voorbeeld.nl', 'mijnapp.herokuapp.com', 'github.com',
     'gebruiker.github.io', 'gitlab.com', 'pypi.org', 'mijnapp.readthedocs.io', 'example.com', 'www.example.com']
    """
    #expect(try guessedDomains(files: ["config/settings.py": settings(hosts)]).isEmpty)
}

@Test(arguments: [
    "https://mijnapp.herokuapp.com", "https://gebruiker.github.io/app", "https://gitlab.com/x/y",
    "https://pypi.org/project/y", "https://y.readthedocs.io/en/latest", "https://example.com",
    "http://localhost:8000", "http://192.168.1.20/app", "http://intranet/app",
])
func rejectedHomepageInPackageJsonYieldsNothing(homepage: String) throws {
    #expect(try guessedDomains(files: ["package.json": "{\"homepage\": \"\(homepage)\"}"]).isEmpty)
}

// MARK: - Combining sources

@Test func projectWithoutAnySourceYieldsEmptyList() throws {
    #expect(try guessedDomains(files: ["README.md": "See https://voorbeeld.nl for more.\n"]).isEmpty)
}

@Test func sameDomainFromTwoSourcesAppearsOnce() throws {
    let files = [
        "CNAME": "voorbeeld.nl\n",
        "package.json": "{\"homepage\": \"https://voorbeeld.nl/app\"}",
        "config/settings.py": settings("['voorbeeld.nl']"),
    ]
    #expect(try guessedDomains(folder: "voorbeeld.nl", files: files) == ["voorbeeld.nl"])
}

@Test func domainsComeInTheOrderOfTheSources() throws {
    let files = [
        "CNAME": "cname.voorbeeld.nl\n",
        "package.json": "{\"homepage\": \"https://package.voorbeeld.nl\"}",
        "pyproject.toml": "[project.urls]\nHomepage = \"https://pyproject.voorbeeld.nl\"\n",
        "config/settings.py": settings("['settings.voorbeeld.nl']"),
    ]
    #expect(try guessedDomains(folder: "folder.voorbeeld.nl", files: files) == [
        "folder.voorbeeld.nl", "cname.voorbeeld.nl", "package.voorbeeld.nl",
        "pyproject.voorbeeld.nl", "settings.voorbeeld.nl",
    ])
}
