import CoreGraphics
import Foundation
import Testing
@testable import ClaudeshellCore

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
