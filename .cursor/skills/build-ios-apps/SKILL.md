---
name: build-ios-apps
description: Build, sign, install, and publish iOS apps using the Vibecode signing service. Use when the user wants to build an iOS app from source, sign an iOS app, install on their iPhone, register a device, set up Apple Developer auth, publish to the App Store or TestFlight, submit for review, or work with the iOS build/sign/distribute/publish pipeline. Also triggers for "test on device", "put this on my phone", "ship it to my iPhone", "publish to App Store", "submit my app", "push to TestFlight", "send for review", or any request to get a Swift/iOS app running on a real device or shipped to App Store Connect.
---

# iOS App Build, Sign, Install & Publish

Build Swift apps, sign them with Apple credentials, install on iPhones via OTA, and publish to App Store Connect (production review or TestFlight).

## CRITICAL RULES

1. **NEVER use Xcode, xcodebuild, or xcrun.** You do not have Xcode access. ALL building is done through the cloud build pipeline via `./ios-cli`.
2. **NEVER make raw HTTP/curl calls to the signing service.** Always use `./ios-cli`. It handles authentication, polling, error handling, and output formatting.
3. **Every iOS build request MUST go through this skill.** When a user says "build an app", "test on my phone", "put this on my iPhone", "ship it", or anything about getting an iOS app running — use this skill exclusively.
4. **Before writing any app that uses a capability or extension, READ [references/capabilities.md](references/capabilities.md).** It has per-capability rules for entitlement files, Info.plist keys, runtime code, and manual portal steps. Skipping it causes silent install/runtime failures that waste build cycles. Also read [references/gotchas.md](references/gotchas.md) for Xcode 26 compile fixes.

## Cloud Agent Setup

1. **Install the CLI** (first run only): `bash .cursor/skills/build-ios-apps/install-cli.sh`
2. **Authenticate**: Set `CHORUS_API_KEY` or `VIBECODE_API_KEY` in Cursor sandbox secrets to your Chorus API key from https://chorus.com/ → Account settings (starts with `chorus_`). Then run:
   ```bash
   export VIBECODE_API_KEY="${CHORUS_API_KEY:-$VIBECODE_API_KEY}"
   .cursor/skills/build-ios-apps/ios-cli login "$VIBECODE_API_KEY"
   ```
3. **CLI path**: Use `.cursor/skills/build-ios-apps/ios-cli` (or `./ios-cli` when cwd is the skill directory).

## Environment

These environment variables are automatically available inside Chorus runners — `ios-cli` picks them up:

- `VIBECODE_API_KEY` — Authentication. Required. Get yours by signing in at https://chorus.com/ → Account settings → reveal and copy the key (starts with `chorus_`). Cloud agents may also expose this as `CHORUS_API_KEY`. When unset (e.g. running locally), persist it once with `./ios-cli login <api-key>` and the CLI reads it from `~/.vibecode/ios/config.json` on subsequent invocations.
- `SIGNING_SERVICE_URL` — Service URL (auto-detected, defaults to `https://ios.chorus.com`)
- `VIBECODE_PROJECT_ID` — Project / agent identifier. Optional for `build` — when unset, the CLI mints a UUID once and persists it in the config file so subsequent local builds share the same project namespace. Required for `sim-preview`. Chorus runners inject this with the agent id automatically.
- `VIBECODE_USER_ID` — Optional. Defaults to the user resolved from the active API key. Set this (or pass `--user <id>`) to target a non-default signing user, or to tie a build to a specific publishing user (see `publish-ios-apps`).

## Flow at a glance

**Default (sim-first):** Build → print the `previewUrl` from build output. No separate sim-preview step, no Apple auth, no device registration, nothing else. The user previews instantly in their chat.

**On-demand device install:** When the user clicks "Install on device" on the preview, chorus posts a visible user chat message in the form `Install this build on my device. (build: <simBuildId>)`. That triggers the **Install-on-Device callback** below, which walks through any missing setup (auth → register → sign) and prints the install URL.

This install message is the only signal that should make the agent run auth/register/sign. Don't run those steps preemptively after a build — defer until the user explicitly asks to install.

## CLI

The `./ios-cli` binary is in this skill directory. Run `./ios-cli --help` for full usage, or `./ios-cli skill` to print this document.

**If `ios-cli` is missing** (the skill bundle didn't ship the binary, or the environment was rebuilt) install a fresh one. The installer detects your platform, verifies the download against a sha256 manifest, and extracts into `./build-ios-apps/`.

```
# macOS / Linux
curl -fsSL https://ios.chorus.com/install.sh | bash
./build-ios-apps/ios-cli --help

# Windows (PowerShell)
irm https://ios.chorus.com/install.ps1 | iex
.\build-ios-apps\ios-cli.exe --help
```

### Output Modes

Controlled by `--output` global flag:

- `--output text` (default) — logfmt `key="value"` pairs, one line per result. Designed for grep and cut.
- `--output json` — Single JSON object per invocation. Designed for jq and programmatic parsing.
- `--quiet` — Print only the primary identifier (ID or URL). For scripting and piping.

Long-running commands print bracketed event markers to stderr:
`[building]`, `[signing]`, `[done]`, `[error]`

Errors: `ERROR: message` on stderr (text mode) or `{"error":"message","code":"ERROR_CODE"}` on stdout (JSON mode). Exit code 1.

### Commands

| Command | Description |
|---|---|
| `./ios-cli login <api-key>` | Persist a vibecode API key locally so subsequent commands work without env vars (no-op inside Chorus, where the env var is already injected) |
| `./ios-cli auth start --username <email> --password <pass>` | Start Apple ID auth (returns sessionId) |
| `./ios-cli auth apikey [--user <id>] --issuer-id <id> --key-id <id> --p8-key <path> --team-id <id>` | Auth with App Store Connect API key. `--user` is optional; defaults to the API-key owner. |
| `./ios-cli auth link [--user <id>]` | Mint a secure website login link (`/login`) so the user can connect Apple on `ios.chorus.com` instead of pasting credentials in chat. Link expires 10 minutes after minting. |
| `./ios-cli auth status <sessionId>` | Poll auth session state |
| `./ios-cli auth respond --session <id> --value <code>` | Submit 2FA code or team selection |
| `./ios-cli build <zip-path>` | Upload source zip, build on cloud macOS, wait until done |
| `./ios-cli sim-preview <buildJobId>` | Re-mint a preview for an existing buildJob. Rarely needed — `./ios-cli build` already emits a tokenized previewUrl in its output. |
| `./ios-cli sign <buildJobId>` | Sign a built app, wait until done, returns install URL |
| `./ios-cli sign --from-sim <simBuildId>` | Resolve a sim-preview's underlying buildJob server-side and sign for device install (Install-on-Device callback) |
| `./ios-cli devices [userId]` | List registered devices |
| `./ios-cli register-apple [userId]` | Sync pending devices with Apple |
| `./ios-cli status build <jobId>` | Check build job status |
| `./ios-cli status sign <buildId>` | Check signing status |
| `./ios-cli logs <buildJobId>` | Fetch build logs — mid-build for status, after failure for errors |
| `./ios-cli crashes --bundle <bundleId> [--build-id <ascBuildId>] [--limit N] [--user <id>]` | List recent TestFlight crash feedback for an app. TestFlight only; production App Store crashes are not exposed. |
| `./ios-cli bootstrap <app-name> <bundle-id> <output-dir>` | Create new SwiftUI project from template |
| `./ios-cli add-spm-package <repo-url> <version> [--product <name>] [--target <name>] [--project <path>] [--version-kind <kind>]` | Add a remote Swift Package Manager dependency to an Xcode project. Writes all required pbxproj sections (remote ref, product dependency, build file, target + project arrays) and is idempotent on (URL, product). |
| `./ios-cli config get` | Print current config |
| `./ios-cli config set <key> <value>` | Set a config value (supports dot notation) |
| `./ios-cli config path` | Print config file path |
| `./ios-cli skill` | Print this skill reference |
| `./ios-cli diagnose <subcommand>` | Inspect pipeline state for a user — auth, enrollment, certs, devices, capabilities, profile. Use this BEFORE guessing why sign or build fails. See [Diagnose subcommands](#diagnose-subcommands). |

### Diagnose subcommands

When sign or build fails with an Apple-side error and you need to inspect state instead of trying random fixes, use `./ios-cli diagnose <subcommand>`. Every subcommand supports `--output json` for machine parsing. None of them mutate Apple-side state.

| Subcommand | Use it when | Output highlights |
|---|---|---|
| `diagnose user [--user <id>]` | "Is this user authed at all? Which auth method? What signing assets are cached?" | `authMethod`, `teamId`, presence flags for cert / private key / profile / SRP session, `srpSession.ageDays`, `devicesCount` |
| `diagnose enrollment [--user <id>]` | "Will the pre-build gate let me through? Is the team paid?" | `status`: `paid` / `free_account` / `revoked` / `insufficient_scope` / `not_registered` / `transient`, with `portalUrl` + `nextActions` |
| `diagnose certs [--user <id>]` | "Which certs does Apple see for this team? Which is currently cached as 'in use'?" | List of `{id, type, displayName, serialNumber, expiresAt, inUse}`. ASC users see dev + dist; GSA users see dev only (legacy dev portal limitation). |
| `diagnose device --udid <udid> [--user <id>]` | "Is this UDID registered with Apple for this team?" | `registered: bool`, `deviceClass`, `status`, `addedDate`. Case-insensitive UDID match. |
| `diagnose capability --bundle-id <id> --entitlement <key> [--user <id>]` | "Is `com.apple.developer.X` enabled on this bundle id?" | `status`: `enabled` / `not_enabled` / `bundle_id_unregistered` / `manual_only` / `noop` / `unknown_entitlement`. For `manual_only` (Family Controls, CarPlay, etc.) returns `manualStep.portalUrl` + `steps`. |
| `diagnose entitlements --bundle-id <id> [--user <id>]` | "Where did the chain break — Apple side, profile side, or both?" | `apple.capabilityTypes[]` vs `profile.entitlements{}`, plus a `diff.{onBoth, onlyOnApple, onlyInProfile}` breakdown. |
| `diagnose profile --bundle-id <id> [--user <id>]` | "What's actually in the cached `.mobileprovision` for this bundle id?" | Decoded `name`, `uuid`, `teamIdentifier`, `appIdName`, `expirationDate`, `deviceCount`, `entitlements`. Returns `available: false` if no sign has run for this bundle id yet. |

All diagnose endpoints require the caller to own the signing-service user (strict tenant isolation). Secrets (p8 bytes, GSA dsid / authToken, srp_session contents, cert bytes) are NEVER returned — only IDs, presence flags, and decoded metadata.

Typical debug loop when sign fails with a managed-capability error:
1. `./ios-cli diagnose capability --bundle-id <id> --entitlement <key>` — is Apple's bundle id flagged for this capability?
2. If `status: manual_only` → follow `manualStep.portalUrl` + `steps` and re-sign.
3. If `status: not_enabled` → the pipeline should auto-enable it on next sign; retry once before chasing other causes.
4. If `status: enabled` but sign still fails → run `./ios-cli diagnose profile --bundle-id <id>` to confirm the cached profile actually carries the entitlement (capability provisioned but profile stale → re-sign forces a fresh profile).

`[userId]` is optional — when omitted the CLI uses the user resolved from the active API key.

### Crash triage

When testers report crashes via TestFlight feedback, use `./ios-cli crashes` to pull the recent submissions without leaving the terminal:

```bash
# All recent crashes for a bundle (default limit 10, max 200)
./ios-cli crashes --bundle com.example.app

# Narrow to a specific build
./ios-cli crashes --bundle com.example.app --build-id <ascBuildId>

# JSON output for scripting
./ios-cli --output json crashes --bundle com.example.app | jq '.topCrashes'
```

Text output prints a summary line, up to five top crash groups (deduplicated by build + device + crash comment), then one line per recent crash entry. JSON output shape: `{"scope":"testflight","count":N,"topCrashes":[...],"crashes":[...]}`. Scope is always `testflight` — production App Store crash reporting is not accessible through this endpoint.

### Error Codes

If a command fails (exit code 1), check the error code:

| Error Code | Meaning | What To Do |
|---|---|---|
| `MISSING_API_KEY` | No API key in env or config | Run `./ios-cli login <api-key>` or set `VIBECODE_API_KEY`. |
| `MISSING_ENV` | Required env var not set | Ensure `VIBECODE_PROJECT_ID` is available. |
| `MISSING_ARG` | Required command argument missing | Check command usage with `--help`. |
| `MISSING_FLAG` | Required `--flag` not provided | Check command usage with `--help`. |
| `UNKNOWN_COMMAND` | Unrecognized command or subcommand | Run `./ios-cli --help` to see available commands. |
| `CONNECTION_FAILED` | Cannot reach the signing service | Check `SIGNING_SERVICE_URL`. Service may be down. Retry after a few seconds. |
| `UNAUTHORIZED` | Invalid or expired API key (401) | Check `VIBECODE_API_KEY`. The key may have been revoked or rotated. |
| `FORBIDDEN` | Access denied (403) | The API key doesn't have permission for this operation. |
| `NOT_FOUND` | Resource not found (404) | The userId, buildJobId, sessionId, or buildId doesn't exist. Verify the ID. |
| `CLIENT_ERROR` | Other client error (4xx) | Check the error message for details. |
| `SERVER_ERROR` | Server error (5xx) | The signing service had an internal error. Retry. If persistent, report the issue. |
| `BUILD_FAILED` | Cloud build failed | Fetch Xcode errors with `./ios-cli logs <jobId>`. Common causes: missing scheme, Swift compiler errors. |
| `BUILD_NOT_READY` | Build hasn't finished yet | Wait for build to complete. Check with `./ios-cli status build <jobId>`. |
| `SIGN_FAILED` | Code signing failed | Read the error message for the specific cause — see Apple GSA codes below. Do NOT default to re-auth; most transient failures resolve on their own. |
| `NO_APPLE_AUTH` | Server says user has no usable Apple credentials | Run the auth flow (Step 1 of First-Time Setup). |
| `SIGN_IN_PROGRESS` | A sign for the same build is already in flight | Wait 10–30s and retry; don't start another sign. |
| `UNEXPECTED_ERROR` | Unknown/unhandled error | Check the error message. May be a bug — retry or report. |

**Auth-specific errors:**
- `auth start` returns `CONNECTION_FAILED` → signing service may be down
- `auth status` returns `state="auth_failed"` → wrong credentials or Apple blocked the login. Try API key auth instead.
- 2FA code rejected → ask user for a fresh code, they expire quickly

### Apple GSA error codes (in sign / auth error messages)

When a sign or auth error message contains `Apple auth error (ec: -XXXXX)`, the numeric `ec` tells you what Apple is saying. **Critical: do NOT default to "ask user to re-auth" on every Apple error — most are transient or user-actionable in other ways.**

| `ec` | Meaning | Right action |
|---|---|---|
| **-22411** | **Apple refused the token** ("This action cannot be completed at this time"). Usually the Apple sign-in session has expired (sessions last about an hour); sometimes Apple is briefly rate-limiting this Apple ID. | **Re-authenticate (`./ios-cli auth start ...` or the website login link) and retry** — a fresh session resolves the expired-session case. If re-auth itself returns -22411, Apple is rate-limiting → wait a few minutes. To avoid hitting it at all, migrate the user to ASC API key auth, which doesn't use Apple-ID sessions. |
| -22415 | Apple server error (rare) | Retry after a moment. |
| -22421 | Invalid anisette data (machineID/OTP mismatch) | Service-side issue — surface error to operator, do not prompt user. |
| -22406 | Incorrect Apple ID or password at SRP | Genuine credential failure. Re-auth IS the right action here. |
| -20101 | Same as -22406 (wrong credentials) | Re-auth. |
| -21669 | Wrong 2FA code | Ask user for a fresh code. |
| -20209 | Account locked | Apple has locked the account — tell user to unlock at `appleid.apple.com`. Re-auth from our side will NOT help. |
| Any other `ec: -…` | Unknown Apple GSA code | Surface verbatim to operator; do not guess. |

**Decision rule for re-auth prompts:** suggest re-authentication when the error is `-22411` (expired Apple sign-in session — the common case), `-22406`, `-20101`, or "No saved Apple authentication session". For `-22411`, if a fresh re-auth also returns `-22411`, stop re-authing and wait a few minutes (Apple is rate-limiting). Every other code has a more correct action than re-auth. The signing-service's own error hints will tell you which case you're in via the appended hint text — read it before deciding.

**ASC API key as escape hatch:** Users on `auth_method=apikey` never hit any of the GSA codes above. If a user complains about frequent re-auth pestering on password auth, suggest migrating to API key with `./ios-cli auth apikey --user <id> --issuer-id <id> --key-id <id> --p8-key <path> --team-id <id>`.

### Output Examples

```bash
# Default (logfmt text)
./ios-cli devices c906084e-...
# → devices="0" registrationUrl="https://ios.chorus.com/register/c906084e-..."

# JSON mode
./ios-cli --output json devices c906084e-...
# → {"devices":[],"registrationUrl":"https://..."}

# Quiet mode (just UDIDs)
./ios-cli --quiet devices c906084e-...
# → (one UDID per line)

# Build with progress events on stderr
./ios-cli build /tmp/source.zip
# stderr: [build] uploading /tmp/source.zip...
# stderr: [build] job abc123 started
# stderr: [building] 30s elapsed, state=building
# stderr: [done] build succeeded
# stdout: buildJobId="abc123" state="built" appUrl="https://..."
```

### Chaining Commands

The full build → sign → install flow:

```bash
# 1. Build (outputs buildJobId)
./ios-cli build /tmp/source.zip
# → buildJobId="abc123" state="built" appUrl="https://..."

# 2. Sign using the buildJobId from step 1
./ios-cli sign abc123
# → buildId="def456" state="signed" installUrl="https://ios.chorus.com/install/def456"

# 3. Give the user the installUrl to open on their iPhone
```

With quiet mode for scripting:

```bash
# Build and capture just the job ID
BUILD_JOB_ID=$(./ios-cli --quiet build /tmp/source.zip)

# Sign and capture just the install URL
INSTALL_URL=$(./ios-cli --quiet sign "$BUILD_JOB_ID")

# Share with user
echo "Install your app: $INSTALL_URL"
```

## State

All state lives at `~/.vibecode/ios/config.json`. Schema: [config-schema.json](references/config-schema.json).

!`cat ~/.vibecode/ios/config.json 2>/dev/null || echo "No config found — run first-time setup."`

## Routing

**Default path** (no auth required): Always follow **Normal Flow** below for any build request. Build, print URL. Done.

**Install-on-Device callback**: When chat receives a message matching `Install this build on my device. (build: <uuid>)`, follow the **Install-on-Device callback** section. That's the only path that invokes auth/register/sign — and it's only invoked by the user clicking "Install on device" on the preview UI.

Do NOT preemptively run the **First-Time Setup** flow after a build. The user might never want to install on device — only previewing in the simulator. First-Time Setup is a sub-routine called from the Install-on-Device callback when prereqs are missing.

---

## First-Time Setup

Walk the user through each step. Update `~/.vibecode/ios/config.json` after each one. **Only run these steps when the Install-on-Device callback says a prerequisite is missing.**

### Step 0: Pre-requisites

The user **must** be enrolled in the Apple Developer Program ($99/year). If they are not, they cannot use this skill. Begin by asking them if they are enrolled. If not, guide them on how to enroll.

### Step 1: Authenticate with Apple

Apple authentication can be completed three ways:
1. Recommended: website flow — run `./ios-cli auth link [--user <id>]`, send the generated `https://ios.chorus.com/login?...` URL, and wait for the user to finish in the browser. The page supports Apple ID/password and App Store Connect API key. The link is valid for 10 minutes.
2. App Store Connect API key — for users who want the API key setup.
3. Apple ID email + password — fallback for users who prefer password sign-in.

If the website flow fails or the user chooses a direct method, continue with the matching CLI flow below.

If the user prefers direct password auth, explain:
> "Your email and password are sent once to Apple to authenticate. They are not stored in your browser — only a session token is saved on the signing service."

Use the password auth flow:

```bash
# Start auth — returns sessionId and userId
./ios-cli --output json auth start --username "user@example.com" --password "their-password"

# Poll until state is "awaiting_2fa"
./ios-cli --output json auth status <sessionId>

# Ask user for the 6-digit code from their Apple device
./ios-cli auth respond --session <sessionId> --value "123456"

# Poll again until state is "awaiting_team"
./ios-cli --output json auth status <sessionId>

# Show team list from the JSON output, ask user to pick (1-based index)
./ios-cli auth respond --session <sessionId> --value "1"
```

If the password flow fails, fall back to **API key auth**:
> "The password login didn't work. You can use an App Store Connect API key instead. Go to App Store Connect > Users and Access > Integrations > Keys to create one."

```bash
./ios-cli auth apikey \
  --issuer-id <issuerID> \
  --key-id <keyID> \
  --p8-key /path/to/AuthKey_XXXX.p8 \
  --team-id <teamId>
```

After auth succeeds, save to config:
```bash
mkdir -p ~/.vibecode/ios
```
Write `config.json` with `activeUser`, `users.{userId}` containing `appleId`, `teamId`, `teamName`.

### Step 2: Register Device

Check if any devices exist:

```bash
./ios-cli --output json devices <userId>
```

If no devices (empty `devices` array in JSON output):
1. Give the user the `registrationUrl` from the JSON output
2. Tell them to open it **on their iPhone** and tap "Register Device"
3. They'll download a profile — guide them: **Settings > General > VPN & Device Management > install the profile**
4. After success page appears, sync with Apple:

```bash
./ios-cli register-apple <userId>
```

Also remind them to **enable Developer Mode**:
> Settings > Privacy & Security > Developer Mode > toggle ON > restart when prompted.

### Step 3: Sign

Run `./ios-cli sign --from-sim <simBuildId>` (the simBuildId came from the install message's `(build: <uuid>)` parenthetical) — see the **Install-on-Device callback** section.

---

## Normal Flow

The default path. No auth, no register, no sign. The user gets a working preview link they can click in any channel (chorus, Telegram, WhatsApp, iMessage, Safari).

### 1. Generate App Icon

Before building, generate an app icon and overwrite the bootstrap template's placeholder at `Assets.xcassets/AppIcon.appiconset/AppIcon.png`. Read the source code you just wrote and identify what makes this app's **value** unique — not its category. Pick the one visual element that would make someone understand what the app does at a glance.

Use Gemini CLI's nanobanana `/icon` command:

```bash
/icon "App icon design for [app description]. [Visual element] with subtle 3D depth. Premium quality, sophisticated, single focal point, subtle lighting" --sizes="1024" --type="app-icon" --style="modern" --corners="sharp"
```

Always include: `Premium quality, sophisticated, single focal point, subtle lighting`. You can add the app's color scheme from the source code if it has one.

**Examples:**
- `/icon "App icon design for streak habit tracker. Minimalist progress rings with subtle 3D depth. Premium quality, sophisticated, single focal point, subtle lighting" --sizes="1024" --type="app-icon" --style="modern" --corners="sharp"`
- `/icon "App icon design for surf forecast app. Ocean wave curling with subtle 3D depth. Premium quality, sophisticated, single focal point, subtle lighting" --sizes="1024" --type="app-icon" --style="modern" --corners="sharp"`
- `/icon "App icon design for split expense tracker. Two overlapping coins with subtle 3D depth. Premium quality, sophisticated, single focal point, subtle lighting" --sizes="1024" --type="app-icon" --style="modern" --corners="sharp"`

Copy the generated PNG into the asset catalog:

```bash
mkdir -p "{project}/Assets.xcassets/AppIcon.appiconset"
cp [generated-icon-path] "{project}/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
cat > "{project}/Assets.xcassets/AppIcon.appiconset/Contents.json" << 'EOF'
{"images":[{"filename":"AppIcon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}
EOF
```

### 2. Build

```bash
cd /path/to/project
zip -r /tmp/source.zip . -x ".git/*" -x "xcuserdata/*" -x "*.xcuserstate"
./ios-cli build /tmp/source.zip
```

The CLI uploads, builds on cloud macOS, and waits until complete. Outputs `buildJobId`, `state`, and `appUrl`.

**If the build fails**, fetch the Xcode compilation errors and fix them:

1. Run `./ios-cli logs <buildJobId>` to get the error lines from the build
2. Fix the errors in your source code based on what the compiler says
3. Re-zip and rebuild: `zip -r /tmp/source.zip . -x ".git/*" -x "xcuserdata/*" -x "*.xcuserstate" && ./ios-cli build /tmp/source.zip`

Do NOT give up after a failed build. Read the errors, fix the code, rebuild. Most build failures are missing imports, type mismatches, or project configuration issues that are straightforward to fix from the compiler output.

**Build environment**: The build server uses **Xcode 26.0.1** on macOS. Builds run with `-sdk iphoneos` and `CODE_SIGNING_ALLOWED=NO`. The scheme is auto-detected from the `.xcodeproj` — for multi-target projects (app + widget extension), ensure the main app scheme is listed first.

Save `buildJobId` to config under the active project.

`./ios-cli build` emits `simBuildId` and `previewUrl` once the build completes. The previewUrl includes a JWT token so it works in any browser (chorus webapp, Telegram, WhatsApp, iMessage, Safari).

### 3. Print previewUrl

**Always include the `previewUrl` verbatim in your reply.** The chorus webapp will auto-open it in the right panel; other channels (Telegram/WhatsApp/iMessage) will render it as a clickable link the user can open in any browser.

The user clicks "Install on device" on the preview itself when they want to install on iPhone — that triggers the **Install-on-Device callback** below. Don't preemptively sign.

---

## Install-on-Device callback

**Trigger**: the user asks to install the build, e.g. `Install this build on my device. (build: <simBuildId>)`. Pull `simBuildId` from the `(build: <uuid>)` parenthetical.

### Steps

1. Run `./ios-cli sign --from-sim <simBuildId>`.
2. Handle the exit code:
   - **Success**: prints `installUrl`. Print it verbatim in your reply. Chorus renders inline "Install on device" + "Preview in simulator" buttons under it; user taps Install on their iPhone.
   - **`NO_APPLE_AUTH`**: server says the user has no usable Apple credentials. Run **First-Time Setup Step 1** (auth flow). Then retry from step 1 above.
   - **`SIGN_FAILED`** (with hint about devices in error message): the user has no registered iPhone yet, or registered devices haven't been Apple-synced. Run **First-Time Setup Step 2** (registration). Then retry from step 1.
   - **`SIGN_IN_PROGRESS`**: a sign is already running for this build. Wait 15s and retry.
   - **`BUILD_NOT_READY`**: the underlying build job isn't `built` yet. Surface a clear error to the user; usually means the build hasn't completed or has expired.

### Re-Sign After New Device

When `register-apple` adds a new UDID to an Apple team, the previous IPA's provisioning profile is stale. Subsequent `sign --from-sim` automatically clears the cached profile and re-signs. No special handling — just rerun the callback steps.

---

## Re-Sign After New Device

When a new device is registered, the current build needs re-signing (the provisioning profile must include the new device UDID).

Check config for the active project's `buildJobId`. If it exists:
> "New device registered. Re-sign your current build to include it?"

Then re-trigger: `./ios-cli sign <buildJobId>`. No rebuild needed.

---

## Creating a New Project

```bash
./ios-cli bootstrap "My App" "com.example.myapp" /path/to/project
```

Creates a SwiftUI project with SwiftData, tests, asset catalogs from the built-in template. Replaces all placeholders with your app name and bundle ID. Initializes a git repo.

Add new `.swift` files directly into the `{App Name}/` directory — Xcode picks them up automatically.

After bootstrapping, save to config:

```bash
./ios-cli config set activeUser <userId>
./ios-cli config set users.<userId>.teamId <teamId>
```

---

## Adding SPM packages

Use `./ios-cli add-spm-package <repo-url> <version>` — the subcommand writes every required pbxproj section for you (remote reference, product dependency, build-file link, target + project arrays). Do **not** hand-edit `project.pbxproj`. The command is idempotent on (URL, product) so re-runs are safe.

Examples:

```bash
# Default (upToNextMajor, infer product from URL, link to the first iOS app target)
./ios-cli add-spm-package https://github.com/supabase/supabase-swift 2.0.0 --product Supabase

# Pin an exact version, target a specific app
./ios-cli add-spm-package https://github.com/realm/realm-swift 10.50.0 \
  --product RealmSwift --target "My App" --version-kind exact

# Track a branch instead of a version
./ios-cli add-spm-package https://github.com/owner/foo main \
  --product Foo --version-kind branch
```

Available `--version-kind` values: `upToNextMajor` (default), `upToNextMinor`, `exact`, `range` (pass version as `X.Y.Z..A.B.C`), `branch`, `revision`. Match what the package's docs recommend rather than defaulting blindly.

After adding the package, `import <ModuleName>` in your Swift source. **The module name is not always the product name** — check the package's README or `Package.swift`. Examples: product `Realm` exposes module `Realm`, but product `RealmSwift` exposes module `RealmSwift`; product `FirebaseFirestore` exposes module `FirebaseFirestore`. Most match 1:1 but verify before importing.

**Multiple products from one package** (e.g., `FirebaseAuth` + `FirebaseFirestore` from `firebase-ios-sdk`): run `./ios-cli add-spm-package` once per product against the same URL. The command detects the existing `XCRemoteSwiftPackageReference` for that URL and reuses its id — so you get one repo reference plus a separate `XCSwiftPackageProductDependency` / `PBXBuildFile` / target-array entry per product. Re-running with a product already attached is a no-op.

Local path packages (`XCLocalSwiftPackageReference` / `package(path:)`) are out of scope — use a different shape.

### What the pipeline does for you

- **Embeds dynamic frameworks.** The pipeline scans `@rpath/<X>.framework` references in the main binary and `<App>.debug.dylib`, copies matching frameworks from `PackageFrameworks/` into `App.app/Frameworks/`. Works for forced-dynamic packages (Realm, RealmSwift, Sentry@dynamic).
- **Skips macro & plugin trust prompts.** `xcodebuild` runs with `-skipMacroValidation -skipPackagePluginValidation`. Packages with macros (TCA, swift-syntax) or buildToolPlugins (SwiftLint) build without intervention.
- **Resigns embedded frameworks** recursively inside extensions, app clips, and watch targets.

**Do NOT add an `Embed Frameworks` (`PBXCopyFilesBuildPhase`) phase yourself.** The pipeline handles it. For static-default packages an explicit embed phase fails the build with `lstat: No such file` because no `.framework` is produced.

**Do not strip the standard runpath.** App targets must keep `LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks"` (the Xcode default). Without it, dyld cannot find the auto-embedded frameworks at launch even though the pipeline copied them in.

### Multi-target apps (extensions, app clips, watch apps)

`packageProductDependencies` is a **per-target** field on each `PBXNativeTarget`. Any non-host target that `import`s an SPM module needs:

- an entry in **that target's** `packageProductDependencies` array
- a `PBXBuildFile` referencing the product
- an entry in **that target's** `PBXFrameworksBuildPhase.files`

The `XCRemoteSwiftPackageReference` and project-level `packageReferences` are added once at the project level and shared.

This applies to widget extensions, app clips, watch apps, watch extensions, share / notification service / notification content / intents / file provider / network / keyboard / iMessage / audio unit / spotlight / today extensions — same rule, no special case per type.

**Dynamic SPM framework consumed by an extension.** Auto-embed scans `@rpath` references in the host's main binary and `<App>.debug.dylib`. **The host target must carry the package as one of its dependencies for the framework to be embedded** — even if the host doesn't directly use the API. So when an extension imports a dynamic SPM product, also add the same `XCSwiftPackageProductDependency` to the host's `packageProductDependencies` and a matching `PBXBuildFile`/Frameworks entry. If you genuinely don't want to call the API from host code, a no-op reference (`_ = ModuleName.self` in the App's init) keeps the symbol from being dead-stripped at link time. The host-target dependency is the load-bearing fix; the symbol reference is a belt-and-suspenders safety check.

### Heavy packages — first build is slow

Cold resolves of Realm, swift-syntax-based packages (TCA, swift-macro-toolkit), Firebase, or large multi-package combos can take 15–40 minutes on Azure. The signing service has a 45-minute deadline — wait rather than cancel.

If the user asks for status mid-build, run `./ios-cli logs <buildJobId>` to surface live Azure progress (resolving packages, compiling targets, etc.). Most "stuck" builds are just slow, not broken.

---

## Adding Supabase as a backend

**When an iOS app needs Supabase as its backend, wire it with `./ios-cli supabase setup` — always. Do not hand-write the `SupabaseClient` config, and do not reuse a generic Supabase database/CRUD integration for the app wiring** (those are for the agent's own queries against a DB — a different concern). `supabase setup` is the only thing that gets the *app* side right: it selects the client-safe **publishable (anon)** key, **refuses a service_role/secret key** (which must never ship inside an app binary), auto-detects a connection already present in the environment so you don't re-prompt for creds, and writes the SPM dependency + Swift glue consistently. Hand-wiring is error-prone — wrong key type, a leaked secret, or a missing SPM package.

The subcommand:

1. Installs the `supabase` CLI on-demand at `~/.vibecode/bin/supabase` if not on `PATH`, SHA-256 verified against a pinned manifest.
2. Authenticates with the user's Supabase Personal Access Token.
3. Links to the user's existing Supabase project (`--project-ref`).
4. Adds `supabase-swift` to the Xcode project as an SPM dependency.
5. Writes `SupabaseClient+App.swift` into the target source directory with the URL and publishable (anon) key as top-level constants plus a ready-to-use `let supabase = SupabaseClient(...)`.
6. Writes `.vibecode/supabase.json` recording the public config (project ref, URL, publishable key).

```bash
./ios-cli supabase setup --token <sbp_…> --project-ref <abc1234>
```

In Swift, just import and use:

```swift
import Supabase
// supabase is a top-level let from SupabaseClient+App.swift
let items: [Item] = try await supabase.from("items").select().execute().value
```

**If the user needs a PAT, give them this exact link — `https://supabase.com/dashboard/account/tokens` — and don't describe dashboard menu navigation (the paths drift; the deep link is stable).**

The PAT lives only in the user's Supabase CLI credential store (never in source). The publishable key is safe to ship in the binary — it's the public anon key. Do not pass a `service_role` key as `--token`; the command refuses keys that aren't client-safe.

After setup, the agent calls `supabase` directly for schema work — migrations, types generation, edge functions, etc. Docs: https://supabase.com/docs

---

## Publishing

For App Store / TestFlight publishing, see [references/publishing.md](references/publishing.md).

### Routing apps (transit, ride-share, navigation)

If the user is building a routing app, the project's pbxproj must declare which transit modes the app supports. Add this build setting:

```
INFOPLIST_KEY_MKDirectionsApplicationSupportedModes = "MKDirectionsModeCar MKDirectionsModeTransit MKDirectionsModeWalking";
```

Pick the subset that matches the app from: `MKDirectionsModeCar`, `MKDirectionsModeTransit`, `MKDirectionsModeWalking`, `MKDirectionsModeBus`, `MKDirectionsModeFerry`, `MKDirectionsModeStreetCar`, `MKDirectionsModePedestrian`, `MKDirectionsModeRideShare`, `MKDirectionsModeBike`, `MKDirectionsModeOther`.

---

## References

- [API Reference](references/api-reference.md) — all signing service endpoints
- [Capabilities & Entitlements](references/capabilities.md) — per-capability rules, entitlements, Info.plist keys, extension matrix
- [Device Registration](references/device-registration.md) — UDID enrollment flow details
- [Config Schema](references/config-schema.json) — config file structure
- [Gotchas](references/gotchas.md) — common issues and fixes
