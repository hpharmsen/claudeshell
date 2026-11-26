import Testing
@testable import MaestroCore

private let home = "/Users/hp"

/// Shaped like the project tables of a real ~/.wezterm.lua, with made-up projects and a trailing tab quirk.
let wezTermFixture = """
local projects = {
    {
        name = '.claude',
        cwd = wezterm.home_dir .. '/.claude',
    },
    {
        name = 'Brainwave',
        cwd = wezterm.home_dir .. '/ai/Brainwave/website',
    },
    {
        name = 'Elevate Curriculum Genie',
        cwd = wezterm.home_dir .. '/proj/elevate/Curriculum Design Tool',
        server_command = './runlocal.sh',
    },
    {
        name = 'Elevate Tony',
        cwd = wezterm.home_dir .. '/proj/elevate/tony',
        server_command = './runlocal.sh',
    },
    {
        name = 'Elevate Translate',
        cwd = wezterm.home_dir .. '/proj/elevate/elevatetranslate',
        server_command = './runlocal.sh',
    },
    {
        name = 'Golfmaster',
        cwd = wezterm.home_dir .. '/Sites/golfmaster',
        server_command = './runlocal.sh',
    },
    {
        name = 'Cityguide.example',
        cwd = wezterm.home_dir .. '/Sites/cityguide.example',
        server_command = './runlocal.sh',
    },
    {
        name = 'Homepage.example',
        cwd = wezterm.home_dir .. '/Sites/homepage.example',
        server_command = './runlocal.sh',
    },
    {
        name = 'Mailbot/de Firma',
        cwd = wezterm.home_dir .. '/proj/mailbot/clients/de-firma',
        server_command = './runlocal.sh',
    },
    {
        name = 'Mailbot/Sandbox',
        cwd = wezterm.home_dir .. '/proj/mailbot/clients/sandbox',
        server_command = './runlocal.sh',
    },
    {
        name = 'Shop.example',
        cwd = wezterm.home_dir .. '/Sites/shop.example',
        server_command = './runlocal.sh',
    },	
}
local simple_projects = {
    'AINews',
    'Autolab',
    'Maestro',
    'Cleanroom',
    'Codelab',
    'Janitor',
    'Keep',
    'Hardprompts',
    'Justai',
    'Justlog',
    'Lifewiki',
    'Mailprocessor',
    'Podcast',
    'Scripts',
    'Security',
    'Research',
}

for _, project in ipairs(simple_projects) do
    table.insert(projects, {
        name = project,
        cwd = wezterm.home_dir .. '/proj/' .. project:lower(),
    })
end
"""

private func path(of name: String, in contents: String = wezTermFixture) -> String? {
    WezTermImporter.parse(contents, home: home).first { $0.name == name }?.path
}

@Test func fixtureYields27Projects() {
    #expect(WezTermImporter.parse(wezTermFixture, home: home).count == 27)
}

@Test func pathKeepsSpaces() {
    #expect(path(of: "Elevate Curriculum Genie") == "/Users/hp/proj/elevate/Curriculum Design Tool")
}

@Test func simpleProjectPointsToLowercasedProjFolder() {
    #expect(path(of: "Justai") == "/Users/hp/proj/justai")
}

@Test func nameWithSlashIsKept() {
    #expect(path(of: "Mailbot/de Firma") == "/Users/hp/proj/mailbot/clients/de-firma")
}

@Test func serverCommandAppearsNowhere() {
    let projects = WezTermImporter.parse(wezTermFixture, home: home)
    #expect(!projects.contains { $0.name.contains("runlocal") || $0.path.contains("runlocal") })
}

@Test func resultIsSortedByteWiseByName() {
    let names = WezTermImporter.parse(wezTermFixture, home: home).map(\.name)
    #expect(names == names.sorted { $0.utf8.lexicographicallyPrecedes($1.utf8) })
}

@Test func dotClaudeSortsFirst() {
    #expect(WezTermImporter.parse(wezTermFixture, home: home).first?.name == ".claude")
}

@Test func uppercaseSortsBeforeLowercase() {
    let contents = "local simple_projects = { 'apple', 'Zebra' }"
    #expect(WezTermImporter.parse(contents, home: home).map(\.name) == ["Zebra", "apple"])
}

@Test func emptyFileYieldsEmptyList() {
    #expect(WezTermImporter.parse("", home: home).isEmpty)
}

@Test func fileWithoutProjectsTableYieldsEmptyList() {
    let contents = "local wezterm = require 'wezterm'\nlocal tabs = { 'zsh', 'claude' }\n"
    #expect(WezTermImporter.parse(contents, home: home).isEmpty)
}

@Test func entryWithoutCwdIsSkipped() {
    let contents = """
    local projects = {
        { name = 'NoFolder' },
        { name = 'Ok', cwd = wezterm.home_dir .. '/ok' },
    }
    """
    #expect(WezTermImporter.parse(contents, home: home) == [ImportedProject(name: "Ok", path: "/Users/hp/ok")])
}

@Test func doubleQuotedStringsAreRecognised() {
    let contents = """
    local projects = { { name = "Double", cwd = wezterm.home_dir .. "/proj/double" } }
    local simple_projects = { "Other" }
    """
    #expect(WezTermImporter.parse(contents, home: home) == [
        ImportedProject(name: "Double", path: "/Users/hp/proj/double"),
        ImportedProject(name: "Other", path: "/Users/hp/proj/other"),
    ])
}

@Test func cwdWithoutHomePrefixIsTakenAsIs() {
    let contents = "local projects = { { name = 'Abs', cwd = '/opt/abs' } }"
    #expect(path(of: "Abs", in: contents) == "/opt/abs")
}

@Test func commentedOutEntriesAreIgnored() {
    let contents = """
    -- local projects = { { name = 'Ghost', cwd = '/ghost' } }
    local projects = {
        -- { name = 'Old', cwd = wezterm.home_dir .. '/old' },
        { name = 'New', cwd = wezterm.home_dir .. '/new' }, -- trailing 'remark'
    }
    local simple_projects = {
        'Keep', -- 'Dropped',
    }
    """
    #expect(WezTermImporter.parse(contents, home: home).map(\.name) == ["Keep", "New"])
}

@Test func doubleDashInsideStringIsNotAComment() {
    let contents = "local projects = { { name = 'a--b', cwd = '/x--y' } }"
    #expect(WezTermImporter.parse(contents, home: home) == [ImportedProject(name: "a--b", path: "/x--y")])
}

@Test func extraWhitespaceIsTolerated() {
    let contents = "local   projects={\n{name='Tight',cwd=wezterm.home_dir..'/tight'},\n{\n\tname   =   'Wide'  ,\n\tcwd  =  wezterm.home_dir   ..   '/wide'\n}\n}"
    #expect(WezTermImporter.parse(contents, home: home) == [
        ImportedProject(name: "Tight", path: "/Users/hp/tight"),
        ImportedProject(name: "Wide", path: "/Users/hp/wide"),
    ])
}
