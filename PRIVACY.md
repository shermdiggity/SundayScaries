# Sunday Scaries privacy policy

Last updated 6 September 2026.

Sunday Scaries is an iOS app that shows the fantasy football leagues you play in. It is
made by one person and has no server. This policy says what the app does with your data,
which is little.

## What the app does not do

- It does not collect, store or transmit any data to the developer. There is no account
  with Sunday Scaries, no analytics, no advertising, no tracking, and no third-party SDK.
- It does not read your contacts, photos, location, microphone or camera.

## What stays on your device

- The usernames, emails or league ids you type, and which leagues you hide or reorder,
  are kept in the app's own preferences on your device.
- Sign-in credentials for ESPN, MyFantasyLeague and Yahoo are kept in the iOS keychain,
  on this device only, excluded from backups. You can remove them at any time with
  Disconnect or Sign out in the app's You sheet, or by deleting the app.
- League data the app has fetched is cached on the device so the app opens with what it
  last knew.

## What leaves your device, and where it goes

The app talks directly to the fantasy platforms you connect, and only to read your
leagues. Nothing passes through the developer.

- **Sleeper**: your Sleeper username, sent to Sleeper's public API.
- **ESPN**: when you sign in, ESPN's own login page is shown inside the app. The app never
  reads what you type there; it keeps only the two session cookies ESPN sets, and sends
  them back to ESPN to read your leagues. Public ESPN leagues are read by id without any
  sign-in.
- **MyFantasyLeague**: your username and password are sent once, over HTTPS, to
  MyFantasyLeague's documented login request. The password is not kept. The cookie it
  returns is kept in the keychain.
- **Fleaflicker**: the email or user id on your Fleaflicker account, sent to
  Fleaflicker's API.
- **Yahoo**: not available in this version.

The app also downloads public NFL data with no personal information in the request: the
player ID crosswalk from DynastyProcess and nflverse, the NFL schedule from nflverse, live
game status from ESPN's public scoreboard, and player headshots from the platforms'
image servers.

Each platform handles the data it receives under its own privacy policy.

## Deleting your data

Deleting the app removes everything above. Disconnect or Sign out in the You sheet
removes a platform's credentials without deleting the app.

## Contact

Open an issue at https://github.com/shermdiggity/SundayScaries.
