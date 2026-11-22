import Foundation
import Testing
@testable import ClaudeshellCore

/// Storage location in a fresh temp directory.
private func tempFileURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("claudeshell-tests-\(UUID().uuidString)")
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

@MainActor @Test func addingInactiveProjectAgainMakesItActiveAtEndOfBar() {
    let (store, projects) = makeStore("a", "b", "c")
    store.setStatus(.inactive, for: projects[0].id)
    #expect(store.add(path: "/p/a") == projects[0])
    #expect(store.status(of: projects[0].id) == .active)
    #expect(store.barProjects == [projects[1], projects[2], projects[0]])
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

@MainActor @Test func moveFromThirdToFirstShiftsRestAndSurvivesReload() {
    let url = tempFileURL()
    let (store, projects) = makeStore("a", "b", "c", "d", at: url)
    store.move(projects[2].id, toBarIndex: 0)
    let expected = [projects[2], projects[0], projects[1], projects[3]]
    #expect(store.barProjects == expected)
    #expect(ProjectStore(fileURL: url).barProjects == expected)
}

@MainActor @Test func moveForwardLandsOnTargetIndex() {
    let (store, projects) = makeStore("a", "b", "c")
    store.move(projects[0].id, toBarIndex: 1)
    #expect(store.barProjects == [projects[1], projects[0], projects[2]])
}

@MainActor @Test func moveBeyondEndClampsToLastBarPosition() {
    let (store, projects) = makeStore("a", "b", "c", "d")
    store.setStatus(.inactive, for: projects[3].id)
    store.move(projects[0].id, toBarIndex: 99)
    #expect(store.barProjects == [projects[1], projects[2], projects[0]])
    #expect(store.inactiveProjects == [projects[3]])
}

@MainActor @Test func moveToNegativeIndexClampsToFirstPosition() {
    let (store, projects) = makeStore("a", "b", "c")
    store.move(projects[2].id, toBarIndex: -5)
    #expect(store.barProjects == [projects[2], projects[0], projects[1]])
}

@MainActor @Test func moveOfInactiveOrUnknownProjectChangesNothing() {
    let (store, projects) = makeStore("a", "b", "c")
    store.setStatus(.inactive, for: projects[2].id)
    store.move(projects[2].id, toBarIndex: 0)
    store.move(UUID(), toBarIndex: 0)
    #expect(store.barProjects == [projects[0], projects[1]])
    #expect(store.inactiveProjects == [projects[2]])
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

@MainActor @Test func restoringInactiveProjectPutsItAtEndOfBar() {
    let (store, projects) = makeStore("a", "b", "c")
    store.setStatus(.inactive, for: projects[0].id)
    store.setStatus(.active, for: projects[0].id)
    #expect(store.barProjects == [projects[1], projects[2], projects[0]])
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
