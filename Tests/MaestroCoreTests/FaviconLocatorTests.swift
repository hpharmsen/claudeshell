import Foundation
import Testing
@testable import MaestroCore

/// The two fixed paths that always close the list for a page on voorbeeld.nl.
private let fixedPaths = ["https://voorbeeld.nl/apple-touch-icon.png", "https://voorbeeld.nl/favicon.ico"]

private func faviconCandidates(_ html: String, page: String = "https://voorbeeld.nl/") -> [String] {
    FaviconLocator.candidates(html: html, pageURL: URL(string: page)!).map(\.absoluteString)
}

@Test func touchIconComesBeforeRelIcon() {
    let html = """
    <html><head>
    <link rel="stylesheet" href="/style.css">
    <link rel="icon" href="/fav.ico">
    <link rel="apple-touch-icon" href="/touch.png">
    </head><body></body></html>
    """
    #expect(faviconCandidates(html) == ["https://voorbeeld.nl/touch.png", "https://voorbeeld.nl/fav.ico"] + fixedPaths)
}

@Test func largestRelIconComesFirst() {
    let html = """
    <link rel="icon" sizes="32x32" href="/icon-32.png">
    <link rel="icon" sizes="192x192" href="/icon-192.png">
    """
    #expect(faviconCandidates(html) == ["https://voorbeeld.nl/icon-192.png", "https://voorbeeld.nl/icon-32.png"] + fixedPaths)
}

@Test func relativeHrefResolvesAgainstThePageURL() {
    let candidates = faviconCandidates("<link rel=\"icon\" href=\"img/icon.png\">", page: "https://voorbeeld.nl/sub/")
    #expect(candidates == ["https://voorbeeld.nl/sub/img/icon.png"] + fixedPaths)
}

@Test func fixedPathsSitOnTheHostRootOfThePage() {
    #expect(faviconCandidates("", page: "https://app.voorbeeld.nl/sub/page.html") == [
        "https://app.voorbeeld.nl/apple-touch-icon.png", "https://app.voorbeeld.nl/favicon.ico",
    ])
}

@Test func absoluteAndProtocolRelativeHrefsKeepTheirHost() {
    let html = """
    <link rel="apple-touch-icon" href="https://cdn.example.org/touch.png">
    <link rel="icon" href="//static.example.org/fav.png">
    """
    #expect(faviconCandidates(html) == ["https://cdn.example.org/touch.png", "https://static.example.org/fav.png"] + fixedPaths)
}

@Test func shortcutIconIsRecognised() {
    #expect(faviconCandidates("<link rel=\"shortcut icon\" href=\"/short.ico\">") == ["https://voorbeeld.nl/short.ico"] + fixedPaths)
}

@Test func reversedAttributeOrderIsRecognised() {
    #expect(faviconCandidates("<link href=\"/reversed.png\" type=\"image/png\" rel=\"icon\">") == ["https://voorbeeld.nl/reversed.png"] + fixedPaths)
}

@Test func singleQuotedAttributesAreRecognised() {
    #expect(faviconCandidates("<link rel='icon' href='/single.png'>") == ["https://voorbeeld.nl/single.png"] + fixedPaths)
}

@Test func shortcutIconWithReversedOrderAndSingleQuotesIsRecognised() {
    #expect(faviconCandidates("<link href='/all.ico' rel='shortcut icon' />") == ["https://voorbeeld.nl/all.ico"] + fixedPaths)
}

@Test func dataAndJavascriptHrefsAreSkipped() {
    let html = """
    <link rel="icon" href="data:image/png;base64,iVBORw0KGgo=">
    <link rel="apple-touch-icon" href="javascript:void(0)">
    <link rel="icon" href="/real.png">
    """
    #expect(faviconCandidates(html) == ["https://voorbeeld.nl/real.png"] + fixedPaths)
}

@Test func nonHttpSchemeIsSkipped() {
    #expect(faviconCandidates("<link rel=\"icon\" href=\"ftp://voorbeeld.nl/icon.png\">") == fixedPaths)
}

@Test func linkWithoutIconRelIsIgnored() {
    let html = "<link rel=\"stylesheet\" href=\"/style.css\"><link rel=\"canonical\" href=\"https://voorbeeld.nl/\">"
    #expect(faviconCandidates(html) == fixedPaths)
}

@Test func emptyHTMLYieldsExactlyTheTwoFixedPaths() {
    #expect(faviconCandidates("") == fixedPaths)
}

@Test func brokenHTMLYieldsExactlyTheTwoFixedPaths() {
    #expect(faviconCandidates("<html><head><link rel=\"icon\" href=") == fixedPaths)
}
