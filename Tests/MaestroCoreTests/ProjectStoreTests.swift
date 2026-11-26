import Foundation
import Testing
@testable import MaestroCore

/// Storage location in a fresh temp directory.
private func tempFileURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("maestro-tests-\(UUID().uuidString)")
        .appendingPathComponent("projects.json")
}

/// Store with projects /p/a, /p/b, ... for the given names.
@MainActor private func makeStore(_ names: String..., at url: URL = tempFileURL()) -> (ProjectStore, [Project]) {
    let store = ProjectStore(fileURL: url)
    return (store, names.map { store.add(path: "/p/\($0)") })
}

// MARK: Adding

@MainActor @Test func addUsesFolderNameActiveStatusFirstColorAndLastPosition() {
    let (store, _) = makeStore("a")
    let project = store.add(path: "/a/b/mijnproject")
    #expect(project.name == "mijnproject")
    #expect(project.path == "/a/b/mijnproject")
    #expect(store.status(of: project.id) == .active)
    #expect(project.color == ColorPalette.colors[1])
    #expect(store.barProjects.last == project)
}

@MainActor @Test func firstProjectGetsFirstColor() {
    let (_, projects) = makeStore("a")
    #expect(projects[0].color == ColorPalette.colors[0])
}

@MainActor @Test func secondProjectGetsDifferentColor() {
    let (_, projects) = makeStore("a", "b")
    #expect(projects[0].color != projects[1].color)
}

@MainActor @Test func seventeenthProjectGetsLeastUsedColor() {
    let store = ProjectStore(fileURL: tempFileURL())
    let first16 = (1...16).map { store.add(path: "/p/\($0)") }
    #expect(first16.map(\.color) == ColorPalette.colors)
    // Color 0 is now used twice, so color 1 is the first least used one.
    store.setColor(ColorPalette.colors[0], for: first16[1].id)
    store.setColor(ColorPalette.colors[1], for: first16[2].id)
    store.setColor(ColorPalette.colors[2], for: first16[3].id)
    store.setColor(ColorPalette.colors[3], for: first16[0].id)
    store.setColor(ColorPalette.colors[0], for: first16[0].id)
    #expect(store.add(path: "/p/17").color == ColorPalette.colors[3])
    #expect(store.add(path: "/p/18").color == ColorPalette.colors[1])
}

@MainActor @Test func addWithExplicitNameUsesThatName() {
    let store = ProjectStore(fileURL: tempFileURL())
    #expect(store.add(path: "/a/b/folder", name: "Mooie naam").name == "Mooie naam")
}

@MainActor @Test func addWithTrailingSlashUsesFolderName() {
    let store = ProjectStore(fileURL: tempFileURL())
    let project = store.add(path: "/a/b/mijnproject/")
    #expect(project.name == "mijnproject")
    #expect(project.path == "/a/b/mijnproject")
}

@MainActor @Test func addWithTrailingSlashFindsExistingProject() {
    let (store, projects) = makeStore("a")
    #expect(store.add(path: "/p/a/") == projects[0])
    #expect(store.projects.count == 1)
}

@MainActor @Test func addWithEmptyPathComponentsFindsExistingProject() {
    let (store, projects) = makeStore("a")
    #expect(store.add(path: "/p//a") == projects[0])
    #expect(store.projects.count == 1)
}

@MainActor @Test func addingActiveProjectAgainChangesNothing() {
    let (store, projects) = makeStore("a", "b")
    store.setStatus(.running, for: projects[1].id)
    store.select(projects[1].id)
    #expect(store.add(path: "/p/a") == projects[0])
    #expect(store.projects == projects)
    #expect(store.status(of: projects[0].id) == .active)
    #expect(store.selectedID == projects[1].id)
}

@MainActor @Test func addingInactiveProjectAgainPutsItBackInTheBar() {
    let (store, projects) = makeStore("a", "b", "c")
    store.setStatus(.inactive, for: projects[0].id)
    #expect(store.add(path: "/p/a") == projects[0])
    #expect(store.status(of: projects[0].id) == .active)
    #expect(store.barProjects == projects)
    #expect(store.inactiveProjects.isEmpty)
}

@MainActor @Test func addingRunningProjectAgainSelectsIt() {
    let (store, projects) = makeStore("a", "b")
    store.setStatus(.running, for: projects[0].id)
    store.add(path: "/p/a")
    #expect(store.projects.count == 2)
    #expect(store.selectedID == projects[0].id)
    #expect(store.status(of: projects[0].id) == .running)
}

@MainActor @Test func addDoesNotSelectOrStartNewProject() {
    let (store, projects) = makeStore("a")
    #expect(store.selectedID == nil)
    #expect(store.status(of: projects[0].id) == .active)
}

@MainActor @Test func sameNameInDifferentFoldersExistSideBySide() {
    let store = ProjectStore(fileURL: tempFileURL())
    let one = store.add(path: "/x/site"), two = store.add(path: "/y/site")
    #expect(one.id != two.id)
    #expect(store.barProjects.map(\.name) == ["site", "site"])
}

// MARK: Order

@MainActor @Test func barIsAlphabeticalWhateverTheOrderOfAdding() {
    let (store, _) = makeStore("delta", "Alfa", "charlie", "Bravo")
    #expect(store.barProjects.map(\.name) == ["Alfa", "Bravo", "charlie", "delta"])
}

@MainActor @Test func barIsAlphabeticalAfterReload() {
    let url = tempFileURL()
    _ = makeStore("delta", "Alfa", "charlie", at: url)
    #expect(ProjectStore(fileURL: url).barProjects.map(\.name) == ["Alfa", "charlie", "delta"])
}

@MainActor @Test func renamedProjectMovesToItsAlphabeticalPlace() {
    let (store, projects) = makeStore("alfa", "bravo", "charlie")
    store.rename(projects[0].id, to: "Zulu")
    #expect(store.barProjects.map(\.name) == ["bravo", "charlie", "Zulu"])
}

@MainActor @Test func numbersInNamesSortByValue() {
    let (store, _) = makeStore("site10", "site2", "site1")
    #expect(store.barProjects.map(\.name) == ["site1", "site2", "site10"])
}

@MainActor @Test func sameNamesSortByFolder() {
    let store = ProjectStore(fileURL: tempFileURL())
    let two = store.add(path: "/y/site"), one = store.add(path: "/x/site")
    #expect(store.barProjects == [one, two])
}

// MARK: Status and selection

@MainActor @Test func runningProjectsLoadAsActiveWithoutSelection() {
    let url = tempFileURL()
    let (store, projects) = makeStore("a", "b", "c", at: url)
    projects.forEach { store.setStatus(.running, for: $0.id) }
    store.select(projects[1].id)
    store.save()
    let loaded = ProjectStore(fileURL: url)
    #expect(loaded.barProjects == projects)
    #expect(projects.allSatisfy { loaded.status(of: $0.id) == .active })
    #expect(loaded.selectedID == nil)
}

@MainActor @Test func inactiveProjectLeavesBarAndAppearsInInactiveList() {
    let (store, projects) = makeStore("a", "b")
    store.setStatus(.inactive, for: projects[0].id)
    #expect(store.barProjects == [projects[1]])
    #expect(store.inactiveProjects == [projects[0]])
    #expect(store.status(of: projects[0].id) == .inactive)
}

@MainActor @Test func inactiveStatusSurvivesReload() {
    let url = tempFileURL()
    let (store, projects) = makeStore("a", "b", at: url)
    store.setStatus(.inactive, for: projects[0].id)
    let loaded = ProjectStore(fileURL: url)
    #expect(loaded.barProjects == [projects[1]])
    #expect(loaded.inactiveProjects == [projects[0]])
}

@MainActor @Test func deactivatingSelectedProjectClearsSelection() {
    let (store, projects) = makeStore("a", "b")
    store.select(projects[0].id)
    store.setStatus(.inactive, for: projects[0].id)
    #expect(store.selectedID == nil)
}

@MainActor @Test func deactivatingOtherProjectKeepsSelection() {
    let (store, projects) = makeStore("a", "b")
    store.select(projects[0].id)
    store.setStatus(.inactive, for: projects[1].id)
    #expect(store.selectedID == projects[0].id)
}

@MainActor @Test func restoringInactiveProjectPutsItBackInAlphabeticalPlace() {
    let (store, projects) = makeStore("a", "b", "c")
    store.setStatus(.inactive, for: projects[0].id)
    store.setStatus(.active, for: projects[0].id)
    #expect(store.barProjects == projects)
    #expect(store.inactiveProjects.isEmpty)
}

@MainActor @Test func switchingBetweenRunningAndActiveKeepsPosition() {
    let (store, projects) = makeStore("a", "b", "c")
    store.setStatus(.running, for: projects[0].id)
    store.setStatus(.active, for: projects[0].id)
    #expect(store.barProjects == projects)
}

@MainActor @Test func selectingInactiveOrUnknownProjectIsIgnored() {
    let (store, projects) = makeStore("a", "b")
    store.setStatus(.inactive, for: projects[1].id)
    store.select(projects[0].id)
    store.select(projects[1].id)
    store.select(UUID())
    #expect(store.selectedID == projects[0].id)
    store.select(nil)
    #expect(store.selectedID == nil)
}

@MainActor @Test func unknownProjectHasNoProjectAndIsInactive() {
    let (store, _) = makeStore("a")
    #expect(store.project(UUID()) == nil)
    #expect(store.status(of: UUID()) == .inactive)
}

// MARK: Removing

@MainActor @Test func removedProjectIsGoneAlsoAfterReload() {
    let url = tempFileURL()
    let (store, projects) = makeStore("a", "b", "c", at: url)
    store.setStatus(.inactive, for: projects[2].id)
    store.remove(projects[0].id)
    store.remove(projects[2].id)
    for candidate in [store, ProjectStore(fileURL: url)] {
        #expect(candidate.projects == [projects[1]])
        #expect(candidate.barProjects == [projects[1]])
        #expect(candidate.inactiveProjects.isEmpty)
        #expect(candidate.project(projects[0].id) == nil)
    }
}

@MainActor @Test func removingSelectedProjectClearsSelection() {
    let (store, projects) = makeStore("a", "b")
    store.select(projects[0].id)
    store.remove(projects[0].id)
    #expect(store.selectedID == nil)
}

// MARK: Name and color

@MainActor @Test func nameAndColorSurviveReload() {
    let url = tempFileURL()
    let (store, projects) = makeStore("a", at: url)
    #expect(store.rename(projects[0].id, to: "Nieuwe naam"))
    store.setColor("#ABCDEF", for: projects[0].id)
    let loaded = ProjectStore(fileURL: url).project(projects[0].id)
    #expect(loaded?.name == "Nieuwe naam")
    #expect(loaded?.color == "#ABCDEF")
}

@MainActor @Test(arguments: ["", "   ", " \t\n"]) func blankNameIsRefused(name: String) {
    let (store, projects) = makeStore("a")
    #expect(!store.rename(projects[0].id, to: name))
    #expect(store.project(projects[0].id)?.name == "a")
}

@MainActor @Test func renameOfUnknownProjectIsRefused() {
    let (store, _) = makeStore("a")
    #expect(!store.rename(UUID(), to: "x"))
}

// MARK: Website and icon state

@MainActor @Test func bareDomainIsStoredWithHTTPS() {
    let (store, projects) = makeStore("a")
    #expect(store.setWebsite("voorbeeld.nl", for: projects[0].id))
    #expect(store.project(projects[0].id)?.website == "https://voorbeeld.nl")
}

@MainActor @Test func websiteWithSchemeIsStoredAsEntered() {
    let (store, projects) = makeStore("a")
    #expect(store.setWebsite("http://voorbeeld.nl/pad", for: projects[0].id))
    #expect(store.project(projects[0].id)?.website == "http://voorbeeld.nl/pad")
}

@MainActor @Test(arguments: ["", "   "]) func blankWebsiteClearsTheWebsite(text: String) {
    let (store, projects) = makeStore("a")
    store.setWebsite("voorbeeld.nl", for: projects[0].id)
    #expect(store.setWebsite(text, for: projects[0].id))
    #expect(store.project(projects[0].id)?.website == nil)
}

@MainActor @Test func websiteWithoutValidHostIsRefusedAndKeepsOldValue() {
    let (store, projects) = makeStore("a")
    store.setWebsite("voorbeeld.nl", for: projects[0].id)
    #expect(!store.setWebsite("geen domein", for: projects[0].id))
    #expect(store.project(projects[0].id)?.website == "https://voorbeeld.nl")
}

@MainActor @Test func websiteAndIconStateSurviveReload() {
    let url = tempFileURL()
    let (store, projects) = makeStore("a", "b", at: url)
    store.setWebsite("voorbeeld.nl", for: projects[0].id)
    store.setIconState(.removed, for: projects[0].id)
    let loaded = ProjectStore(fileURL: url)
    #expect(loaded.project(projects[0].id)?.website == "https://voorbeeld.nl")
    #expect(loaded.project(projects[0].id)?.iconState == .removed)
    #expect(loaded.project(projects[1].id)?.website == nil)
    #expect(loaded.project(projects[1].id)?.iconState == nil)
}

@MainActor @Test func clearedWebsiteAndIconStateSurviveReload() {
    let url = tempFileURL()
    let (store, projects) = makeStore("a", at: url)
    store.setWebsite("voorbeeld.nl", for: projects[0].id)
    store.setIconState(.searched, for: projects[0].id)
    store.setWebsite("", for: projects[0].id)
    store.setIconState(nil, for: projects[0].id)
    #expect(ProjectStore(fileURL: url).projects == projects)
}

@MainActor @Test func setIconStateOfUnknownProjectChangesNothing() {
    let url = tempFileURL()
    let (store, projects) = makeStore("a", at: url)
    store.setIconState(.custom, for: UUID())
    #expect(store.projects == projects)
    #expect(store.project(projects[0].id)?.iconState == nil)
    #expect(ProjectStore(fileURL: url).projects == projects)
}

@MainActor @Test func fileWithoutWebsiteAndIconStateLoadsWithBothEmpty() throws {
    let url = tempFileURL()
    let json = """
        [{"id": "11111111-2222-3333-4444-555555555555", "name": "Bakkerij", "path": "/p/bakkerij",
          "color": "#3B82F6", "status": "active"}]
        """
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(json.utf8).write(to: url)
    let store = ProjectStore(fileURL: url)
    #expect(store.projects.map(\.name) == ["Bakkerij"])
    #expect(store.projects[0].website == nil)
    #expect(store.projects[0].iconState == nil)
}

// MARK: Link overrides

@MainActor @Test func bareDomainIsStoredAsLiveLinkWithHTTPS() {
    let (store, projects) = makeStore("a")
    #expect(store.setLink("voorbeeld.nl", kind: .live, for: projects[0].id))
    #expect(store.project(projects[0].id)?.linkOverrides == [.live: "https://voorbeeld.nl"])
}

@MainActor @Test(arguments: [
    ("localhost:8003", "http://localhost:8003"),
    ("127.0.0.1:9000", "http://127.0.0.1:9000"),
    ("localhost", "http://localhost"),
    ("localhost/pad", "http://localhost/pad"),
    ("LocalHost:8003", "http://LocalHost:8003"),
    ("https://localhost:8443", "https://localhost:8443"),
    ("localhost.voorbeeld.nl", "https://localhost.voorbeeld.nl"),
]) func localLinkGetsHTTP(text: String, expected: String) {
    let (store, projects) = makeStore("a")
    #expect(store.setLink(text, kind: .localhost, for: projects[0].id))
    #expect(store.project(projects[0].id)?.linkOverrides?[.localhost] == expected)
}

@MainActor @Test func linkWithSchemeIsStoredAsEntered() {
    let (store, projects) = makeStore("a")
    #expect(store.setLink("http://voorbeeld.nl/pad", kind: .live, for: projects[0].id))
    #expect(store.project(projects[0].id)?.linkOverrides?[.live] == "http://voorbeeld.nl/pad")
}

@MainActor @Test func linkIsTrimmedBeforeStoring() {
    let (store, projects) = makeStore("a")
    #expect(store.setLink("  voorbeeld.nl/repo\n", kind: .git, for: projects[0].id))
    #expect(store.project(projects[0].id)?.linkOverrides?[.git] == "https://voorbeeld.nl/repo")
}

@MainActor @Test(arguments: ["", "   ", " \t\n"]) func blankLinkStoresEmptyValueThatSurvivesReload(text: String) {
    let url = tempFileURL()
    let (store, projects) = makeStore("a", at: url)
    store.setLink("voorbeeld.nl", kind: .live, for: projects[0].id)
    #expect(store.setLink(text, kind: .live, for: projects[0].id))
    #expect(store.project(projects[0].id)?.linkOverrides == [.live: ""])
    #expect(ProjectStore(fileURL: url).project(projects[0].id)?.linkOverrides == [.live: ""])
}

@MainActor @Test(arguments: ["geen link", "geenlink", "http://", "https://geen link.nl"])
func linkWithoutValidHostIsRefusedAndKeepsOldValue(text: String) {
    let url = tempFileURL()
    let (store, projects) = makeStore("a", at: url)
    store.setLink("voorbeeld.nl", kind: .live, for: projects[0].id)
    #expect(!store.setLink(text, kind: .live, for: projects[0].id))
    #expect(store.project(projects[0].id)?.linkOverrides == [.live: "https://voorbeeld.nl"])
    #expect(ProjectStore(fileURL: url).project(projects[0].id)?.linkOverrides == [.live: "https://voorbeeld.nl"])
}

@MainActor @Test func refusedLinkOnProjectWithoutOverridesLeavesTheFieldEmpty() {
    let (store, projects) = makeStore("a")
    #expect(!store.setLink("geen link", kind: .git, for: projects[0].id))
    #expect(store.project(projects[0].id)?.linkOverrides == nil)
}

@MainActor @Test func setLinkOfUnknownProjectIsRefusedAndChangesNothing() {
    let url = tempFileURL()
    let (store, projects) = makeStore("a", at: url)
    #expect(!store.setLink("voorbeeld.nl", kind: .live, for: UUID()))
    #expect(store.projects == projects)
    #expect(ProjectStore(fileURL: url).projects == projects)
}

@MainActor @Test func linksOfDifferentKindsLiveSideBySideAndSurviveReload() {
    let url = tempFileURL()
    let (store, projects) = makeStore("a", "b", at: url)
    store.setLink("voorbeeld.nl", kind: .live, for: projects[0].id)
    store.setLink("localhost:8003", kind: .localhost, for: projects[0].id)
    store.setLink("voorbeeld.nl/repo", kind: .git, for: projects[0].id)
    let expected: [LinkKind: String] = [.live: "https://voorbeeld.nl", .localhost: "http://localhost:8003",
                                        .git: "https://voorbeeld.nl/repo"]
    let loaded = ProjectStore(fileURL: url)
    #expect(loaded.project(projects[0].id)?.linkOverrides == expected)
    #expect(loaded.project(projects[1].id)?.linkOverrides == nil)
}

@MainActor @Test func clearLinkOverridesClearsAllKindsAndKeepsTheOtherFields() {
    let url = tempFileURL()
    let (store, projects) = makeStore("a", at: url)
    store.setWebsite("voorbeeld.nl", for: projects[0].id)
    store.setIconState(.custom, for: projects[0].id)
    let before = store.project(projects[0].id)
    store.setLink("voorbeeld.nl", kind: .live, for: projects[0].id)
    store.setLink("", kind: .localhost, for: projects[0].id)
    store.setLink("voorbeeld.nl/repo", kind: .git, for: projects[0].id)
    store.clearLinkOverrides(for: projects[0].id)
    #expect(store.project(projects[0].id)?.linkOverrides == nil)
    #expect(store.project(projects[0].id) == before)
    #expect(ProjectStore(fileURL: url).project(projects[0].id) == before)
}

@MainActor @Test func clearLinkOverridesOfUnknownProjectChangesNothing() {
    let (store, projects) = makeStore("a")
    store.setLink("voorbeeld.nl", kind: .live, for: projects[0].id)
    store.clearLinkOverrides(for: UUID())
    #expect(store.project(projects[0].id)?.linkOverrides == [.live: "https://voorbeeld.nl"])
}

@MainActor @Test func localhostIsStillRefusedAsWebsite() {
    let (store, projects) = makeStore("a")
    #expect(!store.setWebsite("localhost:8003", for: projects[0].id))
    #expect(store.project(projects[0].id)?.website == nil)
}

@MainActor @Test func fileWithoutLinkOverridesLoadsWithTheFieldEmpty() throws {
    let url = tempFileURL()
    let json = """
        [{"id": "11111111-2222-3333-4444-555555555555", "name": "Voorbeeld", "path": "/p/voorbeeld",
          "color": "#3B82F6", "website": "https://voorbeeld.nl", "iconState": "searched", "status": "active"}]
        """
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(json.utf8).write(to: url)
    let store = ProjectStore(fileURL: url)
    #expect(store.projects.map(\.name) == ["Voorbeeld"])
    #expect(store.projects[0].linkOverrides == nil)
    #expect(store.setLink("voorbeeld.nl", kind: .live, for: store.projects[0].id))
}

// MARK: Storage

@MainActor @Test func missingFileGivesEmptyStoreAndFirstSaveCreatesFile() {
    let url = tempFileURL()
    let store = ProjectStore(fileURL: url)
    #expect(!store.fileExisted)
    #expect(store.projects.isEmpty)
    #expect(!FileManager.default.fileExists(atPath: url.path))
    store.save()
    #expect(FileManager.default.fileExists(atPath: url.path))
    #expect(ProjectStore(fileURL: url).fileExisted)
}

@MainActor @Test func everyMutationWritesTheFile() {
    let url = tempFileURL()
    let (_, projects) = makeStore("a", at: url)
    #expect(ProjectStore(fileURL: url).projects == projects)
}

@MainActor @Test func brokenJSONGivesEmptyStoreAndIsKeptAsCorruptFile() throws {
    let url = tempFileURL()
    let corruptURL = url.deletingLastPathComponent().appendingPathComponent("projects.corrupt.json")
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("{ kapot".utf8).write(to: url)
    let store = ProjectStore(fileURL: url)
    #expect(store.projects.isEmpty)
    #expect(!FileManager.default.fileExists(atPath: url.path))
    store.add(path: "/p/a")
    #expect(try String(contentsOf: corruptURL, encoding: .utf8) == "{ kapot")
    #expect(ProjectStore(fileURL: url).projects.count == 1)
}

@MainActor @Test func secondCorruptFileReplacesTheFirst() throws {
    let url = tempFileURL()
    let corruptURL = url.deletingLastPathComponent().appendingPathComponent("projects.corrupt.json")
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    for content in ["eerste", "tweede"] {
        try Data(content.utf8).write(to: url)
        #expect(ProjectStore(fileURL: url).projects.isEmpty)
    }
    #expect(try String(contentsOf: corruptURL, encoding: .utf8) == "tweede")
}

// MARK: Next running project

@MainActor @Test func nextRunningIsTheFirstRunningProjectAfterItInBarOrder() {
    let (store, projects) = makeStore("a", "b", "c", "d")
    [0, 2, 3].forEach { store.setStatus(.running, for: projects[$0].id) }
    #expect(store.nextRunning(after: projects[0].id) == projects[2].id)
}

@MainActor @Test func nextRunningWrapsAroundToTheStartOfTheBar() {
    let (store, projects) = makeStore("a", "b", "c")
    [0, 2].forEach { store.setStatus(.running, for: projects[$0].id) }
    #expect(store.nextRunning(after: projects[2].id) == projects[0].id)
}

@MainActor @Test func nextRunningIsNilWhenNothingElseRuns() {
    let (store, projects) = makeStore("a", "b")
    store.setStatus(.running, for: projects[0].id)
    #expect(store.nextRunning(after: projects[0].id) == nil)
    #expect(store.nextRunning(after: UUID()) == nil)
}

@MainActor @Test func nextRunningFollowsTheBarOrderNotTheOrderOfAdding() {
    let (store, projects) = makeStore("c", "a", "b")
    projects.forEach { store.setStatus(.running, for: $0.id) }
    #expect(store.nextRunning(after: projects[1].id) == projects[2].id)
}

// MARK: Last shown project

@MainActor @Test func lastShownProjectSurvivesARestart() {
    let url = tempFileURL()
    let (store, projects) = makeStore("a", "b", at: url)
    store.select(projects[0].id)
    store.select(projects[1].id)
    #expect(store.lastShownID == nil)
    #expect(ProjectStore(fileURL: url).lastShownID == projects[1].id)
}

@MainActor @Test func nothingIsLastShownAfterTheSelectionWasCleared() {
    let url = tempFileURL()
    let (store, projects) = makeStore("a", at: url)
    store.select(projects[0].id)
    store.select(nil)
    #expect(ProjectStore(fileURL: url).lastShownID == nil)
}

@MainActor @Test func nothingIsLastShownWithoutAnEarlierRun() {
    let url = tempFileURL()
    _ = makeStore("a", at: url)
    #expect(ProjectStore(fileURL: url).lastShownID == nil)
}

@MainActor @Test func aProjectThatLeftTheBarOrTheAppIsNotLastShown() {
    for leave in [{ (store: ProjectStore, id: Project.ID) in store.setStatus(.inactive, for: id) },
                  { (store: ProjectStore, id: Project.ID) in store.remove(id) }] {
        let url = tempFileURL()
        let (store, projects) = makeStore("a", at: url)
        store.select(projects[0].id)
        leave(store, projects[0].id)
        #expect(ProjectStore(fileURL: url).lastShownID == nil)
    }
}
