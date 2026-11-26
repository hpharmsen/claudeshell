import CoreGraphics
import Foundation
import Testing
@testable import MaestroCore

@Test func projectRoundTripsThroughJSON() throws {
    let project = Project(name: "Justai", path: "/Users/hp/proj/justai", color: "#3B82F6")
    let decoded = try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(project))
    #expect(decoded.id == project.id)
    #expect(decoded.name == "Justai")
    #expect(decoded.path == "/Users/hp/proj/justai")
    #expect(decoded.color == "#3B82F6")
}

@Test func twoProjectsGetDifferentIDs() {
    #expect(Project(name: "a", path: "/a", color: "#000000").id != Project(name: "a", path: "/a", color: "#000000").id)
}

@Test func projectWithWebsiteAndIconStateRoundTripsThroughJSON() throws {
    let project = Project(name: "Bakkerij", path: "/p/bakkerij", color: "#3B82F6",
                          website: "https://voorbeeld.nl", iconState: .custom)
    let decoded = try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(project))
    #expect(decoded == project)
    #expect(decoded.website == "https://voorbeeld.nl")
    #expect(decoded.iconState == .custom)
}

@Test(arguments: [IconState.searched, .custom, .removed]) func everyIconStateRoundTripsThroughJSON(state: IconState) throws {
    let project = Project(name: "a", path: "/a", color: "#000000", iconState: state)
    #expect(try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(project)).iconState == state)
}

@Test func projectWithoutWebsiteAndIconStateDecodesWithBothEmpty() throws {
    let json = """
        {"id": "11111111-2222-3333-4444-555555555555", "name": "Bakkerij", "path": "/p/bakkerij", "color": "#3B82F6"}
        """
    let decoded = try JSONDecoder().decode(Project.self, from: Data(json.utf8))
    #expect(decoded.name == "Bakkerij")
    #expect(decoded.color == "#3B82F6")
    #expect(decoded.website == nil)
    #expect(decoded.iconState == nil)
}

@Test func newProjectHasNoWebsiteAndNoIconState() {
    let project = Project(name: "a", path: "/a", color: "#000000")
    #expect(project.website == nil)
    #expect(project.iconState == nil)
}

// MARK: Link overrides

@Test func projectWithLinkOverridesRoundTripsThroughJSON() throws {
    let overrides: [LinkKind: String] = [.live: "https://voorbeeld.nl", .localhost: "http://localhost:8003", .git: ""]
    let project = Project(name: "Voorbeeld", path: "/p/voorbeeld", color: "#3B82F6", linkOverrides: overrides)
    let decoded = try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(project))
    #expect(decoded == project)
    #expect(decoded.linkOverrides == overrides)
}

@Test func linkOverridesEncodeAsObjectKeyedByKind() throws {
    let project = Project(name: "Voorbeeld", path: "/p/voorbeeld", color: "#3B82F6",
                          linkOverrides: [.live: "https://voorbeeld.nl", .localhost: "", .git: "https://voorbeeld.nl/repo"])
    let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(project)) as? [String: Any]
    #expect(object?["linkOverrides"] as? [String: String]
        == ["live": "https://voorbeeld.nl", "localhost": "", "git": "https://voorbeeld.nl/repo"])
}

@Test func linkOverridesDecodeFromObjectKeyedByKind() throws {
    let json = """
        {"id": "11111111-2222-3333-4444-555555555555", "name": "Voorbeeld", "path": "/p/voorbeeld", "color": "#3B82F6",
         "linkOverrides": {"live": "https://voorbeeld.nl", "git": ""}}
        """
    let decoded = try JSONDecoder().decode(Project.self, from: Data(json.utf8))
    #expect(decoded.linkOverrides == [.live: "https://voorbeeld.nl", .git: ""])
}

@Test func projectWithoutLinkOverridesDecodesWithTheFieldEmpty() throws {
    let json = """
        {"id": "11111111-2222-3333-4444-555555555555", "name": "Voorbeeld", "path": "/p/voorbeeld", "color": "#3B82F6",
         "website": "https://voorbeeld.nl", "iconState": "searched"}
        """
    let decoded = try JSONDecoder().decode(Project.self, from: Data(json.utf8))
    #expect(decoded.name == "Voorbeeld")
    #expect(decoded.website == "https://voorbeeld.nl")
    #expect(decoded.linkOverrides == nil)
}

@Test func newProjectHasNoLinkOverrides() {
    #expect(Project(name: "a", path: "/a", color: "#000000").linkOverrides == nil)
}

@Test func linkKindHasThreeValues() {
    #expect(LinkKind.allCases == [.live, .localhost, .git])
}

// MARK: Initials

@Test(arguments: [
    ("Golf meester", "GM"),
    ("Research", "Re"),
    ("Justai", "Ju"),
    ("Justlog", "Ju"),
    ("de Bakkers", "DB"),
    ("BrA1n", "Br"),
    ("AINews", "AI"),
    (".claude", "Cl"),
]) func initialsOfProjectName(name: String, expected: String) {
    #expect(Project(name: name, path: "/p/x", color: "#000000").initials == expected)
}

@Test func initialsOfSingleCharacterNameIsThatCharacter() {
    #expect(Project(name: "Q", path: "/p/q", color: "#000000").initials == "Q")
}

@Test func initialsOfThreeWordsUseTheFirstTwo() {
    #expect(Project(name: "Het Groene Loket", path: "/p/loket", color: "#000000").initials == "HG")
}

@Test(arguments: ["mijn site", "mijn.site", "mijn-site", "mijn_site"]) func initialsSplitWordsOnSeparator(name: String) {
    #expect(Project(name: name, path: "/p/site", color: "#000000").initials == "MS")
}

@Test func twoPaneIDsDiffer() {
    #expect(PaneID() != PaneID())
}

@Test func startFrameIsThreeQuartersAndCentered() {
    let frame = startFrame(in: CGRect(x: 0, y: 0, width: 1600, height: 1000))
    #expect(frame == CGRect(x: 200, y: 125, width: 1200, height: 750))
}

@Test func startFrameRespectsScreenOrigin() {
    let frame = startFrame(in: CGRect(x: 100, y: 40, width: 1600, height: 1000))
    #expect(frame == CGRect(x: 300, y: 165, width: 1200, height: 750))
}
