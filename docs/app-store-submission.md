# Sunday Scaries: App Store submission runbook

Written Monday 7 September 2026, from an audit of the project as it stands that day.
The goal it is built around: **TestFlight for Week 1 (Thursday 10 September), on the
App Store for Week 2 (Thursday 17 September).**

The one fact that shapes everything below: in September, a brand-new app takes two to
five days in App Review, and the first build of an external TestFlight group takes one
to seven days in Beta App Review. Neither can wait for Week 1's real data. The App Store
build goes in **this week**, and the screenshots come from the demo data, not from a
Sunday.

---

## 1. The calendar

| Day | What happens |
|---|---|
| **Mon 7 Sep** (today) | Code freeze. Push the kit tag, bump the pin, commit, push, CI green. Create the App Store Connect record. Archive and upload build 1.0 (1). Internal TestFlight is live within the hour. |
| **Tue 8 Sep** | Finish the listing (screenshots, privacy, age rating, review notes). Submit 1.0 (1) for App Review with automatic release. Submit the same build to an external TestFlight group. |
| **Thu 10 Sep** | Week 1 kickoff. First real live game on TestFlight: scoreboard, the minute poll, the widget, the hero's "Up by…". |
| **Sun 13 Sep** | Full Sunday on TestFlight. Log bugs. Do **not** upload a new build for cosmetics. A new build restarts review. |
| **Mon 14 Sep** | If still "Waiting for Review", nothing to do. If "Rejected", answer the same day (section 8). |
| **Tue 15 Sep** | Sleeper flips to Week 2. Watch the hero turn into the Week 1 result, then the week control step forward. |
| **Wed 16 Sep** | If still "In Review", request an expedited review (section 8). |
| **Thu 17 Sep** | Week 2. The app is live. Anything learned on Sunday ships as 1.0.1 afterwards. |

Automatic release, not manual: the goal is "online for Week 2", and an approval that
sits waiting for a button is a day lost.

## 2. What the audit found

The state of the project on 7 September, and what each item needs before the build.

**Must fix before archiving**

- **The kit's v0.2.2 is tagged locally and not on GitHub. The app pins 0.2.1.** v0.2.2
  carries the `projectedPoints` cache fix and the September provider fixes, and the
  working tree now also holds the team-rename fix (`StalenessPolicy.teams`, every
  provider's team list refreshable, `TeamRenameTests`), uncommitted. Commit it and move
  the never-pushed tag onto it, so one tag carries everything. The archive resolves the
  package from GitHub at the pinned version, so without the push and the bump the App
  Store build ships the old kit. Commands in section 3.
- **Six app commits are ahead of `origin/main`, plus today's uncommitted work** (the
  glass card, the finished-week hero, the demo data, the screenshots). CI only runs on a
  push. Commit and push before archiving so the archive matches something CI has built.
- **`Screens/PlatformSignIn.swift` line 48 is 170 characters.** It is a working-tree
  change from another session, and `swiftlint --strict` in CI fails on it. Wrap it before
  the push.
- **The string catalog does not yet hold the new hero lines** ("Up in 2, down in 1.",
  "You went 2-1.", "A clean sweep, 4-0."…). The app is English-only and a missing key
  renders as its own text, so nothing breaks. Build once in Xcode so the catalog syncs,
  then commit `Shared/Localizable.xcstrings`.

**Already right, verified**

- `Info.plist`: `ITSAppUsesNonExemptEncryption` false (no export-compliance prompt),
  background `fetch` with the `BGTaskSchedulerPermittedIdentifiers` entry, the
  `sundayscaries://` scheme, and the launch screen colour.
- Privacy manifests in both targets: no tracking, no collected data, `UserDefaults`
  declared with reason CA92.1.
- Entitlements: the App Group `group.colesherman.SundayScaries` on both targets.
- App icon: 1024 light, dark and tinted, RGB with no alpha.
- iPad: all four orientations declared. iPhone: portrait only.
- The kill switch URL (`config/providers.json` on `main`, read hourly) answers 200 and
  is empty. The repo and the kit repo are public, so the privacy-policy and support URLs
  the app links to resolve.
- Both targets are 1.0 (1). App Store Connect rejects a build whose extension's
  version differs from the app's, so keep them in step on every bump.
- Signing is automatic. This Mac holds only an Apple Development certificate. Xcode
  creates the Apple Distribution certificate on the first Archive → Distribute as long
  as the Apple ID is the Account Holder or an Admin.

**Known and accepted**

- The git root is `SundayScaries/`. `CLAUDE.md`, the specs and `FantasyKit/` sit
  outside version control at the `fantasy/` level. Not a release blocker. Noted in
  `CLAUDE.md` section 8.
- Yahoo is built and gated off (`FeatureFlags.yahooEnabled`). Nothing in the listing
  mentions it.

## 3. Code freeze: the commands

Run from `fantasy/`. Each step is a check that must be green before the next.

```bash
# 1. The kit: tests, commit the rename fix, move the (never pushed) tag onto it, push.
cd FantasyKit
swift test                                   # 291 tests, no network
git add -A && git commit -m "A renamed team shows after a refresh"
git tag -f v0.2.2
git push origin main v0.2.2

# 2. The app: pin 0.2.2 (both places), then resolve.
cd ../SundayScaries
sed -i '' 's/version = 0\.2\.1/version = 0.2.2/' SundayScaries.xcodeproj/project.pbxproj
xcodebuild -resolvePackageDependencies -project SundayScaries.xcodeproj -scheme SundayScaries
grep -n '"version"' SundayScaries.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved   # expect 0.2.2

# 3. The three project checks.
grep -rnE '^\s*import (SwiftUI|UIKit)' ../FantasyKit/Sources/ && exit 1 || echo "core clean"
grep -rnE 'Color\(hex|\.font\(\.system\(size' SundayScaries/ Shared/ SundayScariesWidgets/ && exit 1 || echo "tokens clean"
swiftlint lint --strict --baseline .swiftlint-baseline.json && swiftformat --lint .

# 4. Both configurations build. Release is the one that ships.
xcodebuild build -project SundayScaries.xcodeproj -scheme SundayScaries \
  -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO | grep -E 'error:|BUILD'
xcodebuild build -project SundayScaries.xcodeproj -scheme SundayScaries \
  -destination 'generic/platform=iOS Simulator' -configuration Release CODE_SIGNING_ALLOWED=NO | grep -E 'error:|BUILD'

# 5. Commit and push. CI runs the same lint and Debug build.
git add -A && git commit && git push
```

Then run the app on a **device**, not the simulator, once before archiving: sign in to
Sleeper, open a league, open a player, background the app and come back, add a widget.
Guideline 2.1 says "tested on-device", and the ESPN web view and the App Group are the
two things a simulator does not exercise the same way.

## 4. App Store Connect: the record

Do this once, before the first upload, at appstoreconnect.apple.com.

1. **Certificates, Identifiers & Profiles** (developer.apple.com): confirm two App IDs
   exist with the App Groups capability, `colesherman.SundayScaries` and
   `colesherman.SundayScaries.Widgets`, and the group
   `group.colesherman.SundayScaries`. Automatic signing normally registered these when
   the app first ran on a device. If either is missing, the first Archive → Distribute
   creates it.
2. **My Apps → + → New App.** Platform iOS. Name **Sunday Scaries** (free on the US
   store as of today. Names are first come, first served, so this step is the one to
   do first). Primary language English (U.S.). Bundle ID `colesherman.SundayScaries`.
   SKU `sundayscaries-ios`. Full access.
3. **App Information.** Category: Sports. Secondary: Utilities. Content rights: the
   app *does* display third-party content (your league data, delivered by the platforms
   you connect). Answer Yes and confirm. Age rating: section 6.
4. **Pricing and Availability.** Free. Territories: **United States only** for 1.0.
   Every platform the app reads is US-centric, and EU availability requires the trader
   status declaration. Widen later if anyone asks.
5. **App Privacy.** Privacy policy URL
   `https://github.com/shermdiggity/SundayScaries/blob/main/PRIVACY.md` (the same link
   the You sheet opens). Data collection: **Data Not Collected.** Apple's definition of
   "collected" is data transmitted off the device in a way that you or a partner can
   access. Nothing reaches you: the usernames and session cookies go straight to the
   platform the reader chose, and there is no server. `PRIVACY.md` says exactly this.

## 5. The listing: copy to paste

Limits: name 30, subtitle 30, promotional text 170, keywords 100, description 4000.

**Name**
```
Sunday Scaries
```

**Subtitle** (30)
```
Every fantasy league, one week
```

**Promotional text** (170, editable without a new build)
```
Kickoff is here. Every lineup you own on one screen, and one line at the top that says whether any of them still needs you.
```

**Keywords** (100, no platform names, see section 7)
```
fantasy football,lineup,matchup,league,nfl,sunday,dynasty,keeper,scores,live,projections,aggregator
```

**Description**
```
Most people who play fantasy football play in more than one league, on more than one platform. Each platform has its own app, its own scoring and its own idea of who a player is. Sunday Scaries reads them all and shows one week.

ONE SCREEN
The sky at the top knows what time it is. Under it, one sentence: "One lineup needs you." "Up in 2, down in 1." "You went 3-1." Then a card for every league: the score, how much of each lineup has played, the projections and your odds, updating quietly while games are on.

EVERY LINEUP, CHECKED
An empty slot, a starter on bye, a player ruled out: flagged on the card before kickoff, in every league at once.

YOUR GUYS, AND WHO IS COMING FOR YOU
The players you start across all your leagues, ranked by how much of your Sunday they decide. The players starting against you, the same way. A kicker you own in three leagues finally gets his due.

A LEAGUE, IN FULL
Tap a card for the scoreboard, both lineups slot by slot, the win probability, your record, points for, place and luck, the power ranking, everyone else's matchup this week and your whole season with the result of every game.

A PLAYER, UNDER ANY RULES
Tap any player for their season: every week, what they did and what was projected, scored under whichever of your leagues you choose. Six catches are a different number in a half-PPR league than a full one.

WIDGETS
The score and the players who matter, on your home screen and lock screen, refreshed while games are on.

WORKS WITH
Sleeper (just your username), ESPN Fantasy (sign in on ESPN's own page, or add public leagues by ID with no sign-in), MyFantasyLeague and Fleaflicker.

PRIVATE BY CONSTRUCTION
No account with us, no server, no analytics, no ads. The app talks directly to the platforms you connect and keeps credentials in the iOS keychain on this device only. The privacy policy is two screens long and you can read the source.

Not affiliated with Sleeper, ESPN, MyFantasyLeague, Fleaflicker or the NFL.
```

**Support URL** `https://github.com/shermdiggity/SundayScaries/issues`
**Marketing URL** `https://github.com/shermdiggity/SundayScaries`
**Copyright** `2026 Cole Sherman`
**Version** `1.0`

**Screenshots.** Upload from `docs/appstore/`. Only two sizes are required in 2026:
the 6.9-inch iPhone set (1320×2868) and the 13-inch iPad set (2064×2752). App Store
Connect scales them for every smaller device. The 6.5-inch and 12.9-inch folders are
regenerated too and are optional. Order, iPhone:

1. `iphone-week.png` (Sunday afternoon, "Up in 2, down in 1.")
2. `iphone-league.png` (the live scoreboard and both lineups)
3. `iphone-player.png` (a player's season, scored under a league)
4. `iphone-week-final.png` (Tuesday, "You went 2-1.")
5. `iphone-week-morning.png` (Sunday morning, "One lineup needs you.")
6. `iphone-account.png` (the You sheet)

iPad: `ipad-week.png`, `ipad-league.png`. No app preview video. Not needed.

All of them come from the demo data (`-sw.demo live | morning | final`, DEBUG only) and
show the app exactly as it renders, which is what guideline 2.3.3 asks. To regenerate:

```bash
# Boot the two simulators, build Debug, install, then per screenshot:
xcrun simctl status_bar <udid> override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4
xcrun simctl launch <udid> colesherman.SundayScaries -sw.demo live -sw.debugHour 16.3 -sw.debugOpen league/demo-sleeper
sleep 9 && xcrun simctl io <udid> screenshot out.png
# Flatten to RGB (App Store Connect rejects alpha): PIL, Image.open(p).convert("RGB").save(p)
```

## 6. Age rating

The questionnaire changed in 2025 (tiers 4+, 9+, 13+, 16+, 18+, with new questions on
in-app controls, capabilities, medical topics and violence). Answers for this app, all
of which resolve to **4+**:

| Question | Answer | Why |
|---|---|---|
| Violence, sexual content, profanity, horror, drugs, alcohol | None | Sports scores and names. |
| Gambling | No | No wagering, no simulated gambling. Reading a fantasy league is not a contest the app runs. |
| Contests | No | The app runs none. The leagues live on the platforms. |
| Unrestricted web access | No | The only web view is ESPN's sign-in page, opened for that purpose. |
| Medical or wellness | No | |
| User-generated content, messaging, chat, AI chatbot | No | |
| In-app controls (parental) | None | |
| Made for Kids | No | |

## 7. The review-risk register

What a reviewer could raise, in order of likelihood, and what the answer is.

**5.2.2 Third-party sites and services (ESPN).** "Ensure that you are specifically
permitted to do so under the service's terms of use. Authorization must be provided
upon request." ESPN has no API programme, so there is no authorization to produce.
Mitigations already in place: the sign-in is ESPN's own page, untouched. The app reads
only the reader's own leagues. The review notes say so plainly. The kill switch can turn
ESPN off in an hour without a build. Several shipping apps sync ESPN this way. If a
reviewer asks for authorization, the honest reply is that there is none to give and the
feature reads the user's own data at their request, and the fallback is a 1.0 with ESPN
disabled by the switch while the appeal runs. Sleeper's API is public and documented.
MyFantasyLeague documents its login for third-party clients. Fleaflicker's API is
public.

**5.2.1 Intellectual property (NFL team logos, player headshots).** Team defenses show
the NFL club logo from Sleeper's CDN, and players show their platform headshot. Sleeper
is licensed. This app is not. Headshots are what every fantasy app shows and are a low
risk. The club logos are the one thing a reviewer could point at, and they appear in the
league screenshot (Steelers, Broncos). Option if it is raised or if you want zero
exposure before submitting: render defenses as a two-letter team monogram in the team's
colour, the way platforms already get a monogram, about twenty lines in `Headshot`. Not
done today because it changes the product's look. Your call.

**5.2.1 / 2.3.7 Trademarks in metadata.** The name, subtitle and keywords above carry
no platform name. The description says "Works with Sleeper, ESPN Fantasy…" which is a
compatibility statement, and ends with the non-affiliation line. Do not add platform
names to keywords to chase search.

**4.8 Sign in with Apple.** Not required. The app has no primary account. The exception
"your app is a client for a specific third-party service and users are required to sign
in to their… third-party account directly to access their content" is this app exactly.
Say so in the notes so nobody has to work it out.

**2.1 Completeness (the reviewer must see leagues).** Give them a Sleeper username in
the review notes. Yours works: Sleeper is public, no password exists, and the reviewer
types it into the welcome card. Without it they see the connect screen and nothing else,
which is the classic 2.1 rejection.

**2.5.4 Background modes.** `fetch` is declared and used: BGAppRefresh keeps the widget
file moving. One sentence in the notes.

**2.3.3 Screenshots must show the app.** They do. They are captures of the running app
with demo data, no frames, no marketing text.

**5.1.1 Privacy.** Policy URL set, labels "Data Not Collected", manifests present, no
tracking. The one thing to double-check on the form: no SDKs, so no third-party
tracking domains.

**Trademark outside Apple.** "Sunday Scaries" is a registered CBD brand and there is a
Steam game of the same name. Neither is in the App Store and Apple only checks App Store
uniqueness. A trademark holder could object later. The app is free, in a different
class and non-commercial, so the exposure is small, but it exists.

## 8. Build, upload, TestFlight, submit

**Archive and upload** (first time, use Xcode. It creates the distribution certificate
and the profiles):

1. Select the `SundayScaries` scheme and the destination **Any iOS Device (arm64)**.
2. Product → Archive.
3. Organizer → Distribute App → **App Store Connect** → Upload. Leave "Upload your
   app's symbols" and "Manage version and build number" on. Automatic signing.
4. Processing takes 10 to 30 minutes. You get an email, and the build appears under
   TestFlight → iOS builds.

The command-line equivalent, for the second time onwards:

```bash
xcodebuild archive -project SundayScaries.xcodeproj -scheme SundayScaries \
  -destination 'generic/platform=iOS' -archivePath build/SundayScaries.xcarchive \
  -allowProvisioningUpdates
cat > build/ExportOptions.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>7MV3786NJP</string>
</dict></plist>
EOF
xcodebuild -exportArchive -archivePath build/SundayScaries.xcarchive \
  -exportOptionsPlist build/ExportOptions.plist -exportPath build/export -allowProvisioningUpdates
```

Every upload needs a new build number: bump `CURRENT_PROJECT_VERSION` in **both**
targets (`1` → `2`), or let "Manage version and build number" do it.

**TestFlight, internal (Week 1).** TestFlight → Internal Testing → + group "Week 1".
Add testers. They must be App Store Connect users on the team (Users and Access → +,
role Customer Support is the least you can give, up to 100). Enable "automatic
distribution" so every processed build goes to them. No review. They get the invite
email as soon as the build finishes processing.

**TestFlight, external.** External Testing → + group "Friends" → add emails (up to
10,000) or turn on the public link. The first build of each version goes through Beta
App Review: one to seven days in September. Fill "What to Test":

```
Sunday Scaries shows every fantasy league you play in on one screen. Connect Sleeper with just your username. Watch a Sunday: scores update every minute while a game is on, the sentence at the top changes from "Every lineup is set" to "Up in 2, down in 1" to "You went 2-1" on Tuesday. Add the widget. Tell me anything that looks wrong, especially on a lineup with an empty slot or a player on bye.
```

**Submit for App Review.** App Store → 1.0 Prepare for Submission. Select the build.
Version release: **Automatically release this version.** Phased release: off (it only
applies to updates). App Review Information:

- Sign-in required: **Yes.** Username: your Sleeper username. Password: `none` with the
  note explaining why (the field is mandatory).
- Contact: your name, phone, email.
- Notes:

```
Sunday Scaries reads the fantasy football leagues a person already plays in and shows them on one screen. There is no account with us and no server.

TO SEE LEAGUES: on the first screen tap Sleeper and enter the username above. Sleeper's API is public and no password exists. Your leagues load in a few seconds. Tap any league card for the full matchup, tap any player for their season.

ESPN (optional): the ESPN card opens ESPN's own login page in a web view. The app never reads the form. It keeps only the two session cookies ESPN sets, in the keychain, to read that person's own leagues. Public ESPN leagues can be added by league ID with no sign-in. Nothing about the review needs an ESPN account.

Sign in with Apple is not offered because the app has no primary account (guideline 4.8: the app is a client for third-party services the user signs in to directly).

Background fetch keeps the home-screen widget's data current between opens (BGAppRefreshTask).

Privacy: nothing is collected. The privacy policy and the source are linked from the You sheet (person icon, top right).

During the NFL week the first screen changes with the games: before kickoff it reports whether every lineup is set, during games it reports the standing, and after the week it reports the result.
```

Attachments: none needed. If a reviewer asks how the ESPN sign-in works, a 30-second
screen recording of it answers faster than text.

**If rejected.** Read the exact guideline number. Reply in Resolution Center the same
day. Most first rejections are a question (a demo account that did not work, a
screenshot mismatch) and clear on the reply without a new build. If a code change is
needed, fix it, bump the build, upload, and the version re-enters the queue at the
front more often than not. If on Wed 16 Sep the status is still In Review, use
Contact Us → App Review → Request Expedited Review with "time-sensitive event: NFL Week
2 begins 17 September, and the app's purpose is the live week". Expedites are granted
for event-tied launches more often than the form suggests.

## 9. After approval

- **Watch the first live day.** Xcode → Organizer → Crashes pulls in crash logs from
  App Store and TestFlight users automatically. Open it on Sunday evening.
- **The kill switch.** If ESPN breaks or a takedown request arrives, edit
  `config/providers.json` on `main`:
  ```json
  { "disabled": { "espn": "ESPN changed their sign-in. A fix is on the way." } }
  ```
  Every app reads it within the hour and shows that sentence in place of the ESPN
  leagues. No build, no review.
- **1.0.1.** Collect everything Week 1 teaches on TestFlight, ship one update the
  following week. Updates review faster than a first submission.
- **Keep the string catalog in sync** and both targets on the same version and build
  number for every upload.

## 10. Checklist

Print this and tick it.

- [ ] Kit rename fix committed, v0.2.2 moved onto it and pushed. Pin bumped in `project.pbxproj` and `Package.resolved`
- [ ] `PlatformSignIn.swift:48` wrapped. Lint and format green locally
- [ ] Debug and Release build. `swift test` in the kit passes
- [ ] String catalog synced from an Xcode build and committed
- [ ] All commits pushed. CI green
- [ ] Ran on a device: Sleeper sign-in, a league, a player, a widget, background and return
- [ ] App Store Connect record created. Name reserved
- [ ] Archive uploaded. Build processed
- [ ] Internal TestFlight group with testers. Build distributed
- [ ] External group created. "What to Test" filled. Submitted for Beta App Review
- [ ] Screenshots uploaded (6.9-inch ×6, 13-inch ×2)
- [ ] Listing copy pasted. URLs resolve
- [ ] App Privacy: Data Not Collected. Policy URL set
- [ ] Age rating questionnaire answered (4+)
- [ ] Content rights answered
- [ ] Review notes and Sleeper username entered
- [ ] Automatic release selected. Submitted for review
- [ ] Wed 16 Sep: expedite if still In Review
