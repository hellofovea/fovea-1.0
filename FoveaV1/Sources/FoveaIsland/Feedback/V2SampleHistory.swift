import Foundation

// Oct 24, Ryan: "There are definitely always more than one request sent by the user every agent
// session, but right now in our mockup, there's only one request sent by the user in every chat."
// Every sample session on the board, and the sample chats a request goes to (or the search opens),
// was asked before the request it shows now: each earlier exchange with the answer as the agent
// wrote it and what it did for it. The outline at the right (Notion's) shows from two requests.

enum V2SampleHistory {
    /// The board's sample sessions' earlier exchanges, by session.
    static var sessions: [String: [V2Turn]] { sessionTurns.mapValues(turns) }

    /// A sample chat's exchanges so far, oldest first, by chat (`AgentChat.id`).
    static func chat(_ id: String) -> [V2SampleTurn]? { chatTurns[id] }

    /// Sample exchanges as a session's history, numbered from the first.
    static func turns(_ samples: [V2SampleTurn]) -> [V2Turn] {
        samples.enumerated().map { i, turn in
            V2Turn(id: i, question: turn.question, result: nil, answer: turn.answer, work: turn.work)
        }
    }

    private static func step(_ kind: StepKind, _ object: String? = nil, added: Int? = nil, removed: Int? = nil,
                             passed: Bool? = nil, note: String? = nil) -> V2WorkEntry {
        .step(AgentLiveStep(kind: kind, object: object, added: added, removed: removed, passed: passed, note: note))
    }

    private static func turn(_ question: String, _ answer: String, seconds: Int, _ entries: [V2WorkEntry]) -> V2SampleTurn {
        V2SampleTurn(question: question, answer: answer, work: entries.isEmpty ? nil : V2Work(seconds: seconds, entries: entries))
    }

    // MARK: The board's sessions (AgentBoard.tasks), before their request now

    private static let sessionTurns: [String: [V2SampleTurn]] = [
        "t-paste": [
            turn("Show a countdown on Paste not found before the words go.", """
            Paste not found now counts down from 5 before it lets the words go, and the bar says so.

            - The ring empties over the 5 seconds, in `PasteNotFoundBar.swift`.
            - A click on the bar keeps the words, as before.
            """, seconds: 74, [
                step(.read, "PasteNotFoundBar.swift"),
                step(.edit, "PasteNotFoundBar.swift", added: 22, removed: 3),
                step(.build, "swift build", passed: true),
            ]),
            turn("Make it 8 seconds, not 5.", """
            It counts down from 8 now. The number lives in `Tokens.Paste.countdown`, so it's one place to change.
            """, seconds: 18, [
                step(.search, "countdown", note: "2 files"),
                step(.edit, "Tokens.swift", added: 1, removed: 1),
            ]),
        ],
        "t-snapshots": [
            turn("Which snapshot tests fail on CI?", """
            Two fail on CI only, both in `SnapshotTests`:

            - `testIslandExpanded`
            - `testBoardBadges`

            They pass here; on CI each is off by a few pixels at the edges.
            """, seconds: 52, [
                step(.run, "gh run view --log-failed", passed: true),
                step(.read, "SnapshotTests.swift"),
            ]),
            turn("Run them on a 1x display here and see if they fail too.", """
            They fail here too at 1x, by the same pixels. So it's the scale, not the runner's fonts.
            """, seconds: 96, [
                .remark("I'll render them at 1x the way CI does."),
                step(.test, "swift test --filter SnapshotTests", passed: false),
            ]),
        ],
        "t-shortcuts": [
            turn("Where do the shortcuts get saved now?", """
            In `ShortcutStore`, as a JSON blob in UserDefaults under `shortcuts.v2`. Nothing saves until you leave the page.
            """, seconds: 21, [
                step(.search, "ShortcutStore", note: "3 files"),
                step(.read, "ShortcutStore.swift"),
            ]),
            turn("Show the keys as they're pressed, before they're saved.", """
            The recorder shows each key as it goes down, and the chord once it's whole.

            - `ShortcutRecorder` draws the keys held so far, in the page's key style.
            - Releasing them all with no key besides the modifiers puts the old shortcut back.
            """, seconds: 88, [
                step(.read, "ShortcutRecorder.swift"),
                step(.edit, "ShortcutRecorder.swift", added: 31, removed: 6),
                step(.build, "swift build", passed: true),
            ]),
        ],
        "t-payload": [
            turn("Why is the second referent first in the payload?", """
            The compiler sorts referents by their thumbnail's file name, and the second one's was written first.

            - `PayloadCompiler.compile` calls `sorted { $0.thumbnail < $1.thumbnail }`.
            - It should be the draw order, which each referent already keeps as `index`.
            """, seconds: 63, [
                step(.read, "PayloadCompiler.swift"),
                step(.search, "sorted {", note: "4 files"),
                .remark("The order comes from the thumbnails' names, not the drawing."),
            ]),
            turn("Write a test that fails for it first.", """
            Added `PayloadTests.ordersReferentsByDrawOrder`. It fails as expected: the payload starts with referent 2.
            """, seconds: 40, [
                step(.create, "PayloadTests.swift", added: 27, removed: 0),
                step(.test, "swift test --filter PayloadTests", passed: false),
            ]),
        ],
        "t-launch": [
            turn("Who are we up against on the landing page?", """
            Three pages people will compare us with: Linear's Method, Raycast's home page and Superwhisper's.

            - All three lead with speed.
            - None of them shows pointing at something on the screen.
            """, seconds: 140, [
                step(.web, "linear.app/method"),
                step(.web, "raycast.com"),
                step(.web, "superwhisper.com"),
            ]),
            turn("Keep it to one line for the headline.", """
            Noted: one line for the headline, the subhead under it carries the rest. I'll draft both once I've read the pages again.
            """, seconds: 9, []),
        ],
        "t-docs": [
            turn("List every page in the docs.", """
            42 pages, in four sections: Getting started (6), Shortcuts (9), Agents (17) and Settings (10).
            """, seconds: 33, [
                step(.list, "docs/", note: "42 files"),
            ]),
            turn("Which of them link outside the site?", """
            31 of them, 118 links in all. Most go to Apple's and the agents' own docs.
            """, seconds: 58, [
                step(.search, "](https://", note: "31 files"),
            ]),
        ],
        "t-tokens": [
            turn("Where are the colors defined?", """
            In `Tokens.swift`: the window's ink and canvas, and the island's whites at their opacities. Every view is meant to read them from there.
            """, seconds: 17, [
                step(.read, "Tokens.swift"),
            ]),
            turn("And which views read them?", """
            41 of the 56 views read `Tokens.Colors`. The other 15 draw no color of their own, or set one in place, which is what you asked me to list next.
            """, seconds: 46, [
                step(.search, "Tokens.Colors", note: "41 files"),
            ]),
        ],
        "t-hero": [
            turn("Write three headlines for the hero.", """
            Three, shortest first:

            1. Point at it. Say it.
            2. Show your agent what you mean.
            3. Circle it, say it, it's sent to your agent.
            """, seconds: 35, [
                step(.read, "Hero.tsx"),
            ]),
            turn("Use the first, and put it in.", """
            The hero reads "Point at it. Say it." now, in `Hero.tsx`. The subhead is unchanged and wraps to two lines.
            """, seconds: 28, [
                step(.edit, "Hero.tsx", added: 2, removed: 2),
                step(.run, "npm run build", passed: true),
            ]),
        ],
    ]

    // MARK: Chats (ChatBook), oldest first; the last is where the chat is now

    private static let chatTurns: [String: [V2SampleTurn]] = [
        // The code request's chat: asked twice before Fovea sends the ears request to it.
        "cc-notch-ears": [
            turn("Why do the notch's ears look taller than the menu bar?", """
            They're drawn 22 pt tall everywhere, and this display's menu bar is 24 pt, so they stop short of it on this one and overshoot on the 13-inch.

            - The 22 is fixed in `IslandShape.swift`.
            - `ScreenMetrics.menuBarHeight` already has the real height.
            """, seconds: 58, [
                step(.search, "22", note: "3 files"),
                step(.read, "IslandShape.swift"),
                step(.read, "ScreenMetrics.swift"),
            ]),
            turn("Show me where the ears are drawn.", """
            In `IslandShape.path(in:)`, the two arcs at the top corners. `earHeight` sets how far down they go, `earRadius` how round they are.
            """, seconds: 14, [
                step(.read, "IslandShape.swift"),
            ]),
        ],
        "cx-investors": [
            turn("Pull last month's numbers from the dashboard export.", """
            From `export-sept.csv`:

            - 1,284 people on the waitlist, up 31%
            - 212 in the beta, 64% of them using it weekly
            - $0 revenue, as planned
            """, seconds: 41, [
                step(.read, "export-sept.csv"),
            ]),
            turn("Draft the update from them, five short paragraphs.", """
            Drafted it in `investor-update-oct.md`: the numbers, what shipped (the notch and the first run), what's next (Fovea 1.0's beta), one ask (intros to design teams), and thanks.
            """, seconds: 77, [
                step(.create, "investor-update-oct.md", added: 38, removed: 0),
            ]),
            turn("Make the ask the first thing they read.", """
            The ask leads now: "We're looking for intros to design teams who live in Claude Code." The numbers follow it.
            """, seconds: 19, [
                step(.edit, "investor-update-oct.md", added: 4, removed: 4),
            ]),
        ],
        "cc-gaze-drift": [
            turn("Why does the gaze point drift right after a few minutes?", """
            The calibration is fit once, at the start, and the head moves: by minute five the user has leaned in about 4 cm and the fit no longer holds.

            - The drift follows the head's distance in `pose.log`.
            - The eyes alone hold steady.
            """, seconds: 132, [
                step(.read, "pose.log"),
                step(.read, "Calibration.swift"),
                .remark("The drift tracks the head's distance, not time."),
            ]),
            turn("Refit it when the head moves more than 2 cm.", """
            It refits now when the head has moved 2 cm from where it was calibrated, using the last 30 fixations as the points. The drift stays under 1° over ten minutes in the recorded session.
            """, seconds: 210, [
                step(.edit, "Calibration.swift", added: 46, removed: 8),
                step(.test, "swift test --filter Calibration", passed: true),
            ]),
        ],
        "cx-delivery": [
            turn("List the delivery channels we have.", """
            Four, one adapter each:

            1. The agent's own CLI or API
            2. A local process (IPC)
            3. The clipboard and the keyboard
            4. UI automation
            """, seconds: 12, [
                step(.list, "Sources/Delivery", note: "4 files"),
            ]),
            turn("Put them behind one protocol.", """
            They share `DeliveryChannel` now: `deliver(_ payload:) async throws -> DeliveryReceipt`. Adding a destination touches only its own adapter.

            - The receipt says Delivered for the first two, Sent for the others.
            """, seconds: 156, [
                step(.create, "DeliveryChannel.swift", added: 24, removed: 0),
                step(.edit, "ClipboardChannel.swift", added: 9, removed: 14),
                step(.edit, "AutomationChannel.swift", added: 8, removed: 12),
                step(.build, "swift build", passed: true),
            ]),
        ],
        "cc-gaze-papers": [
            turn("Find the papers on appearance-based gaze estimation from the last two years.", """
            Six that matter, the newest first. The two most cited:

            - *GazeTR* (2024): a transformer on the face crop, 3.9° error on MPIIFaceGaze.
            - *L2CS-Net* (2023): two losses per angle, 3.92°.
            """, seconds: 95, [
                step(.web, "arxiv.org"),
                step(.web, "paperswithcode.com"),
            ]),
            turn("Which of them run on a laptop's camera in real time?", """
            L2CS-Net, at about 40 frames a second on an M2. GazeTR needs the GPU for 20.
            """, seconds: 38, [
                step(.read, "papers.md"),
            ]),
        ],
        "cc-thread": [
            turn("Outline a launch thread in six posts.", """
            1. The problem: explaining *where* to an agent
            2. Point, say it, it's sent
            3. The notch, where it lives
            4. A real request, start to finish
            5. What it works with
            6. The link and the waitlist
            """, seconds: 26, []),
            turn("Write the first post.", """
            "You can see the bug. Your agent can't. Fovea lets you point at it and say what's wrong, and it goes to Claude Code with the screenshot."
            """, seconds: 15, []),
        ],
    ]
}
