---
name: mobile-cicd-pipeline
description: Build mobile CI/CD on self-hosted GitHub Actions runners we own — a Mac runner archiving to TestFlight, this Linux box building Android for TestApp.io — instead of paying for cloud macOS minutes. Use when asked to add or fix mobile CI/CD, set up a self-hosted or Mac runner, register a GitHub Actions runner, ship to TestFlight or TestApp.io, "get off Codemagic", replace Codemagic/Bitrise/cloud macOS, sign an iOS build in CI, or debug errSecInternalComponent, an ASC 409 bundle-version collision, a simulator boot timeout, or a build that uploaded but testers can't see. Also triggers on runner group, org-level runner, register a second runner, registration token, runner offline, job stuck in Queued, the runner won't pick up the job, ANDROID_HOME, SDK location not found, Play Console upload.
---

# Mobile CI/CD on runners we own

## The principle

**We own the compute. The vendors keep only the distribution.**

Cloud macOS minutes are the cost being eliminated — Codemagic's free tier, GitHub's
~$0.08/min macOS runners, Bitrise. A MacBook that already exists, already has Xcode,
already holds the signing identity, and already sits on the desk builds the same
archive for zero marginal cost. Same for Android: a Linux box with a JDK and an SDK
is a complete Android CI.

**TestFlight and TestApp.io stay.** They are not compute — they are *distribution*:
Apple's tester delivery is the only legal route onto an iPhone, and TestApp.io's
link/QR install is the cheapest route onto an Android device. Nothing about owning
the runner changes where the artifact goes.

What this replaces: `codemagic.yaml` + `POST https://api.codemagic.io/builds`,
`runs-on: macos-latest`, and any per-minute mobile-build bill.

## Day one — the order that works

Each step exists to stop the next one from being a wasted run.

1. **Look at what you already have:** `cat ~/actions-runner/.runner` (Mac) /
   `cat ~/prod/.runner/.runner` (this box). Repo-scoped or org-level decides
   reuse-vs-second-instance, and it is the thing most often misremembered.
2. **Register / grant the runner** (next section) and confirm it reports `online`
   **carrying the exact label your `runs-on` asks for**. A label no runner carries does
   not fail a job — it QUEUES, with no red check and no email. Never merge a workflow
   ahead of its runner; leave it on `ubuntu-latest` until the label is live.
3. **Put the ASC `.p8` on the Mac** — `~/.appstoreconnect/private_keys/` or
   `~/.private_keys/`. Check *which*; they are not interchangeable per key.
4. **Create the repo secrets/vars** ("Secrets the workflows read", below).
5. **Create `ExportOptions.plist`** with `destination: upload` (gotcha 5) —
   `templates/ExportOptions.plist`.
6. **Add the workflow, adapted to the repo shape** — monorepo vs single-platform, see
   the note above the skeletons. Wrong `paths:` = never fires.
7. **Push (or `workflow_dispatch`)** and `gh run watch`.
8. **Verify at ASC / TestApp.io.** Green is not proof (gotcha 6) — see "Verify an
   upload", below.
9. **Symbol upload + release naming** — see "Observability (required)" below. A crash
   pipeline that ships symbols on a *later* run is a pipeline that never symbolicates
   the build people are actually running.

Two runbooks written out for exactly this, worth reading before writing your own:
`/home/justin/code/coworking-mng-not-shit/ios/RUNNER-SETUP.md` (Mac, second instance)
and `/home/justin/code/coworking-mng-not-shit/android/RUNNER-SETUP.md` (Linux, reuse
vs. new instance, plus the flip step that turns the lane on).

Rollback — removing a runner is three commands and leaves other instances alone:

```bash
cd <runner dir> && ./svc.sh stop && ./svc.sh uninstall
./config.sh remove --token <fresh registration token>
```

## Observability (required)

Read `observability` for the contract, `observability-sentry` for the SDK init and the caps.
The CI's share is three things, and all three are load-bearing.

**1. Upload symbols INSIDE the build that made the artefact.** Not a later job, not a manual
step. The dSYM/mapping only matches the exact binary that produced it, and a crash from an
un-uploaded build is a list of hex addresses forever.

```yaml
# iOS — after archive, before/alongside the upload step
- run: |
    npx @sentry/cli debug-files upload --include-sources \
      --org "$SENTRY_ORG" --project kommonz-ios "$ARCHIVE_PATH/dSYMs"
  env: { SENTRY_AUTH_TOKEN: "${{ secrets.SENTRY_AUTH_TOKEN }}", SENTRY_ORG: "${{ vars.SENTRY_ORG }}" }

# Android — R8/ProGuard mapping, after assembleRelease/bundleRelease
- run: |
    npx @sentry/cli upload-proguard \
      --org "$SENTRY_ORG" --project kommonz-android \
      app/build/outputs/mapping/release/mapping.txt
  env: { SENTRY_AUTH_TOKEN: "${{ secrets.SENTRY_AUTH_TOKEN }}", SENTRY_ORG: "${{ vars.SENTRY_ORG }}" }
```

`SENTRY_AUTH_TOKEN` is a **repo secret** on each runner (`gh secret set`), never the value from
`~/.config/sentry.env` pasted into a workflow file. Self-hosted Sentry cannot symbolicate iOS or
fetch Android system symbols at all — SaaS is not a preference here, it is the reason mobile works.

**2. Release naming is the join key.** `<project>@<version>+<build>` — the SAME string in the
symbol upload, in the SDK's `release`, and in the store build. If they differ by one character the
symbols exist and are never applied. `dist` = the build number.

**3. Environment and keys come from the BUILD CONFIG, never hardcoded.** Debug/TestFlight/App Store
are three `SENTRY_ENVIRONMENT` values read from `Info.plist` / `BuildConfig`. The **PostHog and
Sentry production keys ship only in release builds** — a debug build that reports into the prod
project poisons the funnel and burns the error quota, and a simulator run that records a session
replay is a privacy incident with your own face in it.

Also: the app's bundle ids and its two Sentry project slugs belong in the product's
`manifest.yaml` under `mobile:` and `errors:` — the dashboard shows crash-free rate per surface,
and a surface with no manifest row is a surface nobody watches.

## Topology

| Lane | Runs on | Why |
|---|---|---|
| **iOS release** (archive → TestFlight) | **The Mac**, `runs-on: [self-hosted, macOS]` | Apple hardware is a hard requirement. The runner runs as the Mac's login user, so it reuses the *local* signing assets: `~/.private_keys/AuthKey_<id>.p8`, the login keychain, the Xcode-managed profiles. Nothing to import, nothing to base64 into a secret. |
| **Android release** (signed AAB/APK → TestApp.io) | **The Linux box**, `runs-on: [self-hosted, Linux, X64]` — or `ubuntu-latest` | A plain JVM build. No proprietary hardware, no vendor bill worth avoiding. Self-hosted buys a warm Gradle daemon (~3:20 → ~90s). GitHub-hosted buys ephemerality and unbounded parallelism. Both are defensible — see "When NOT to". |
| **PR gate** (compile / unit tests) | **`ubuntu-latest`, deliberately** | A PR check must never queue behind a sleeping Mac or a production deploy holding the one shared runner. Free, parallel, ephemeral. Do not move this. |

The Mac: `ssh mac` (user `justinclapperton`), arm64, Xcode 26.3, `/opt/homebrew/bin/xcodegen`,
ASC keys in `~/.appstoreconnect/private_keys/` and `~/.private_keys/`, keychain password
at `~/.config/keychain-pass` (mode 600).

The Linux box: runner at `~/prod/.runner` as the systemd **--user** unit
`github-runner.service` (user unit on purpose — deploy jobs call `systemctl --user`
from inside a job, which only works in this user's session). Android toolchain: JDK at `~/android-tooling/jdk` (Temurin 17). ⚠️ **Two** SDK trees
exist and they are different directories — `~/android-tooling/sdk` (built by
`~/android-tooling/setup.sh`, what local dev uses) and `~/android-sdk` (what the
existing runner's `~/prod/.runner/.env` sets `ANDROID_HOME` to). Both carry platforms
35/36. Pin one explicitly in the job `env:` rather than inheriting.

## Runner registration

**A runner registered to one repo cannot serve another.** The config is baked into
`.runner` at registration time; there is no way to add a repo to a repo-scoped runner.
Check what you have before assuming:

```bash
cat ~/actions-runner/.runner        # on the Mac
cat ~/prod/.runner/.runner          # on this box
# "gitHubUrl": ".../owner/REPO"  -> repo-scoped, serves that repo ONLY
# "gitHubUrl": ".../owner"       -> org-level; "poolName" is a runner GROUP, not a scope
```

An **org-level** runner in a *restricted* group looks scoped but isn't — the fix is one
API call to add the repo to the group, **no reinstall, no re-registration**:

```bash
# repo id: gh api repos/OWNER/REPO --jq .id
env -u GITHUB_TOKEN gh api -X PUT \
  /orgs/OWNER/actions/runner-groups/<groupId>/repositories/<repoId>
# labels can also be added live, no re-register:
env -u GITHUB_TOKEN gh api -X POST /orgs/OWNER/actions/runners/<runnerId>/labels \
  -f 'labels[]=macOS-coworking'
```

### Register a SECOND repo-scoped runner (own directory, distinct labels)

Use when: one machine, a handful of repos, you want each lane isolated and the blast
radius of a bad job contained. Each instance is its own directory, its own service,
its own `_work`.

```bash
ssh mac
mkdir -p ~/actions-runner-coworking && cd ~/actions-runner-coworking
# Match the version already running on the machine, or take the newest:
# https://github.com/actions/runner/releases/latest
curl -o r.tar.gz -L https://github.com/actions/runner/releases/download/v2.336.0/actions-runner-osx-arm64-2.336.0.tar.gz
tar xzf r.tar.gz && rm r.tar.gz

TOKEN=$(env -u GITHUB_TOKEN gh api -X POST \
  /repos/LaserFocused-ee/coworking-ios/actions/runners/registration-token --jq .token)

./config.sh --url https://github.com/LaserFocused-ee/coworking-ios \
  --token "$TOKEN" --name mac-coworking \
  --labels self-hosted,macOS,coworking --work _work --unattended --replace

./svc.sh install && ./svc.sh start     # macOS LaunchAgent
./svc.sh status
# ⚠️ LaunchAgent, NOT a daemon: it starts when the login user signs in. A Mac that
# reboots to the login window has NO runner until someone logs in — jobs queue, and
# it looks identical to gotcha 10's benign "asleep" case. Enable auto-login, or
# expect a manual login after every reboot.
```

Linux equivalent is identical except the `linux-x64` tarball and, if the box already
runs a `--user` systemd unit, copying that unit pattern rather than `./svc.sh install`
(which writes a root system unit and breaks `systemctl --user` from inside jobs).

### Register at ORG level (one runner, many repos)

Use when: more than a couple of repos need the same machine, or new repos keep
appearing. One install, grant access per repo afterwards.

```bash
TOKEN=$(env -u GITHUB_TOKEN gh api -X POST \
  /orgs/LaserFocused-ee/actions/runners/registration-token --jq .token)

./config.sh --url https://github.com/LaserFocused-ee \
  --token "$TOKEN" --name mac-laserfocused \
  --runnergroup Default --labels self-hosted,macOS \
  --work _work --unattended --replace
./svc.sh install && ./svc.sh start
```

⚠️ **Check the group before you trust the name.** An enterprise-managed org can have
**two** groups called `Default` — LaserFocused-ee does: id 1 (`inherited: false`,
`visibility: all`) and id 3 (`inherited: true`, `visibility: selected`). Registering
into the wrong one gives you a runner that is online and still never picks up a job —
the same "Queued forever" symptom you would otherwise blame on a sleeping Mac.

```bash
env -u GITHUB_TOKEN gh api /orgs/OWNER/actions/runner-groups \
  --jq '.runner_groups[]|{id,name,visibility,inherited}'   # pick the non-inherited one
```

A group with `visibility: all` is immediately usable by every repo; a `selected` one
needs the `PUT .../repositories/<repoId>` call above. Confirm visibility *after*
registering, not before.

**Choosing:** org-level for anything that will grow (fewer installs, one place to
update, access is an API call). Repo-scoped when you want hard isolation — a
release runner holding a production keystore shouldn't be reachable by an
unrelated repo's PR job.

**Verify:**
```bash
env -u GITHUB_TOKEN gh api /orgs/OWNER/actions/runners --jq '.runners[]|{name,status,labels:[.labels[].name]}'
env -u GITHUB_TOKEN gh api /repos/OWNER/REPO/actions/runners --jq '.runners[]|{name,status}'
```

### Secrets the workflows read

`env -u GITHUB_TOKEN` is **mandatory** on every `gh` write on this box: the enterprise
PAT exported in the environment 403s on org/repo writes, and unsetting it falls back to
the authorised `gh` login. Without it you get an unexplained 403.

```bash
# iOS. Values are already exported in ~/.zshrc as LASER_FOCUSED_ASC_KEY_ID
# (88TUBS56N8) and LASER_FOCUSED_ASC_ISSUER_ID. The .p8 itself never becomes a
# secret — it stays on the Mac (and at ~/.config/appstoreconnect/ on this box).
printf %s "$LASER_FOCUSED_ASC_KEY_ID"    | env -u GITHUB_TOKEN gh secret set ASC_KEY_ID    -R OWNER/REPO
printf %s "$LASER_FOCUSED_ASC_ISSUER_ID" | env -u GITHUB_TOKEN gh secret set ASC_ISSUER_ID -R OWNER/REPO

# Backend config baked into the binary. These are PUBLIC client values, so `gh
# variable set` is the honest home; `gh secret set` also works (coworking-ios uses
# secrets so the workflow reads them the same way on both platforms).
env -u GITHUB_TOKEN gh variable set SUPABASE_URL      -R OWNER/REPO --body "https://<ref>.supabase.co"
env -u GITHUB_TOKEN gh variable set SUPABASE_ANON_KEY -R OWNER/REPO --body "<anon key>"

# Android: signing + distribution (prompted interactively, nothing in shell history)
base64 -w0 release.keystore | env -u GITHUB_TOKEN gh secret set ANDROID_KEYSTORE_BASE64 -R OWNER/REPO
for n in ANDROID_KEYSTORE_PASSWORD ANDROID_KEY_ALIAS ANDROID_KEY_PASSWORD \
         TESTAPPIO_API_TOKEN TESTAPPIO_APP_ID; do
  env -u GITHUB_TOKEN gh secret set "$n" -R OWNER/REPO
done

# Names only, values never printed — do this BEFORE the first push.
env -u GITHUB_TOKEN gh secret list   -R OWNER/REPO
env -u GITHUB_TOKEN gh variable list -R OWNER/REPO
```

Org secrets do **not** silently cover you: LaserFocused-ee has exactly two, both
hyperglot deploy keys. A repo with `total_count: 0` fails the first run.

## The gotchas — each with the failure it prevents

Every one of these was paid for once. A reader who skips them pays again.

1. **`security unlock-keychain -p "$(cat ~/.config/keychain-pass)" ~/Library/Keychains/login.keychain-db`, before any signing.**
   *Prevents:* the login keychain is locked for non-interactive sessions (which is
   what a runner job is), so `codesign` cannot read the private key and the archive
   fails. Works when you `ssh` in by hand and type a password; fails in CI.

2. **`security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$(cat ~/.config/keychain-pass)" ~/Library/Keychains/login.keychain-db`, every run.**
   *Prevents:* `errSecInternalComponent` during archive **after the tests passed** —
   the classic "it compiled, why won't it sign". Unlocking is not enough; a key whose
   partition list omits `codesign` refuses non-interactive use. The ACL survives
   reboots but not every keychain reset, so re-assert it. The call is idempotent.
   *(Seen 2026-08-22 on Sentry.framework.)*

3. **`xcodegen generate` before building.**
   *Prevents:* "project not found", or worse, building a stale `.xcodeproj`. The
   project is generated from `project.yml` and is **not committed** — a fresh
   checkout simply has no `.xcodeproj`. Use the absolute path
   `/opt/homebrew/bin/xcodegen`. **This generalises to every tool you invoke on the
   runner**, not just xcodegen: `run:` steps are non-login shells, so `~/.zshrc` never
   applies. `node` in particular is nvm-managed
   (`~/.nvm/versions/node/<v>/bin/node`) and is on PATH only for an interactive login —
   an existing runner that works today may simply have inherited the login environment
   when its LaunchAgent was loaded; a freshly registered one will not.

4. **`CFBundleVersion` / `CURRENT_PROJECT_VERSION` = `$(date +%s)`.**
   *Prevents:* ASC **409, "bundle version already used"** — Apple requires the build
   number to strictly increase across uploads. Epoch is unique and monotonic for free.
   `MARKETING_VERSION` stays on its human track ("1.0"). ⚠️ See gotcha 4b.

   **4b. Check that the build-setting override actually reaches the plist.** If
   `project.yml`'s `info.properties` doesn't declare
   `CFBundleVersion: "$(CURRENT_PROJECT_VERSION)"`, XcodeGen bakes the **literal**
   value into `Generated/Info.plist` and `xcodebuild … CURRENT_PROJECT_VERSION=$NEXT`
   is a silent no-op — every upload collides at version 1. Either add that line to
   `project.yml`, or stamp the plist directly after generating:
   ```bash
   /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEXT" Generated/Info.plist
   ```
   *(hyperglot declares it; coworking does not — this is the one real divergence
   between the two worked references.)*

5. **`ExportOptions.plist` with `destination: upload`.**
   *Prevents:* a green job that delivered nothing. Without it you get an `.ipa` on
   disk and Apple never hears from you. This one key is what makes
   `xcodebuild -exportArchive` a *delivery*. Template in `templates/ExportOptions.plist`.

6. **The pipeline ENDS at the upload. It never waits in-build for Apple processing.**
   *Prevents:* burning runner wall-clock on Apple's queue, and — the real reason —
   a **false green**. Apple accepts the delivery in ~30s and can *async-reject* it
   minutes later (ITMS-90683 and friends), by **email only**. Codemagic's declarative
   `publishing:` block reported success on deliveries Apple then rejected. Poll ASC
   afterwards to verify; do not encode a wait in the build.

7. **Attach the build to the internal tester group after upload, non-fatally.**
   *Prevents:* "the build uploaded but nobody can see it". A TestFlight internal group
   with `hasAccessToAllBuilds: false` does **not** auto-include new builds. The
   post-upload script (`templates/attach-build-to-testflight.mjs`) adds it. Its failure
   is a `::warning::`, never a build failure — a transient ASC error must not turn a
   successful upload red. **Check the group first**; if `hasAccessToAllBuilds: true`
   you don't need the script at all.

8. **Simulator tests create and delete their OWN device, boot it explicitly, and `xcrun simctl bootstatus -b` before `xcodebuild test`.**
   *Prevents:* two things. (a) Trashing the Mac's own simulators — this is somebody's
   actual workstation. (b) `"Failed to prepare device … Timed out trying to boot
   simulator"` — `xcodebuild` allows a cold device 60s, and a first boot on a busy Mac
   exceeds it. Boot it yourself and wait. `trap` the cleanup on `EXIT` so a failed test
   doesn't leak a device.

9. **Do not pin a runtime for the test device.**
   *Prevents:* a dropped SDK silently pinning you to a dead runtime, and
   `"Unable to find a device"` (exit 70) when `OS:latest` resolves to a version with
   no simulator for your chosen device type. Give `simctl create` a device type and no
   runtime; it picks the newest that device supports. *(Local, interactive builds are
   the opposite case — there you often must pin, e.g. `OS=18.5`.)*

10. **If the Mac is asleep the job QUEUES until the runner reconnects. Document it; do not engineer around it.**
    *Prevents:* a 2am "CI is broken" panic over a laptop lid. A queued job is correct
    behaviour — it runs when the machine comes back. This is also exactly why the PR
    gate stays on `ubuntu-latest`.

11. **`concurrency:` group per workflow with `cancel-in-progress: false`.**
    *Prevents:* cancelling a half-finished upload. A cancelled archive is recoverable;
    a cancelled mid-flight ASC delivery leaves a build number burnt and a partial
    upload at Apple. PR gates are the inverse — there `cancel-in-progress: true` is
    right, because superseded PR checks are pure waste.

12. **`paths:` filters so an iOS-only change doesn't fire the Android release, and vice versa.**
    *Prevents:* a doc typo shipping two TestFlight builds and burning tester goodwill.
    In a single-platform repo the filter still earns its place by not firing on
    `.md`-only commits.

**13 (Linux self-hosted only, no counterpart in the reference).** **Scrub the keystore
and `key.properties` in an `if: always()` step.** *Prevents:* the persistent-runner
version of a credential leak. `ubuntu-latest` is destroyed after the job; a self-hosted
`_work` directory is not. `checkout@v4` does `git clean -ffdx` at the *start* of the
next run, so between runs a **PR build landing in the same workspace picks up
`key.properties` and silently signs with the production release key**. This is the item
that turns self-hosted Android from "slightly worse" into "actively dangerous".

## First run on a Mac that has never signed this app

Gotchas 1–13 assume the Mac already holds a signing identity. **It does not, the first
time a given app builds there** — and that path fails three times in a row, each with a
different error, and #16 disguises itself as #15 so you fix it twice and it still fails.
All four were paid for on 2026-08-22 porting `coworking-ios` onto the same Mac that had
been building `hyperglot-book-reader` without issue for months.

**14. The generated project has no development team.**
*Signature:* `error: Signing for "<Target>" requires a development team. Select a
development team in the Signing & Capabilities editor.` at `GatherProvisioningInputs`,
seconds into the archive.
*Cause:* XcodeGen writes the project from `project.yml`, which typically never declares
`DEVELOPMENT_TEAM`. Codemagic injected it via `xcode-project use-profiles`; nothing on
our runner does.
*Fix:* put it in `project.yml` under the target's `settings.base`, not as an
`xcodebuild` flag — that also fixes signing for a human opening the project locally.
```yaml
    settings:
      base:
        DEVELOPMENT_TEAM: "6FKN6D7964"
        CODE_SIGN_STYLE: Automatic
```
*Get the team from Apple, never from notes:* it is the `seedId` of the bundle id —
`GET /v1/bundleIds`, match `attributes.identifier`. A Mac that has built for other
clients holds their distribution certs too (this one had Routific's `278KNLS5VW`), so a
guess signs against the wrong team and fails confusingly much later.

**15. `set-key-partition-list` cannot grant an ACL to a key that does not exist yet.**
*Signature:* `errSecInternalComponent` at `CodeSign`, on an identity named
`Apple Development: Created via API` — minted seconds earlier **in the same build**.
*Cause:* gotcha 2 runs *before* the archive. On a machine with no identity,
`-allowProvisioningUpdates` mints the certificate *during* the archive, i.e. after that
call already ran.
*Fix:* archive, and on failure re-assert the ACL over the now-existing key and archive
once. On every later run the identity exists, attempt one succeeds, the retry never runs.
```bash
archive() { xcodebuild archive … -allowProvisioningUpdates …; }
if ! archive; then
  echo "::warning::re-asserting codesign ACL over newly minted identity, retrying once"
  <unlock + set-key-partition-list over every keychain>
  archive
fi
```

**16. The minted identity can land in a keychain you never unlocked.**
*Signature:* identical to #15 — `errSecInternalComponent` at `CodeSign` — but it
persists **after** the #15 retry. That identical signature is the trap: it reads as "the
ACL fix didn't work", so the instinct is to re-fix #15.
*Cause:* Xcode puts the new key in whichever keychain it picks, not necessarily `login`.
Here it went to `lfos-sign.keychain-db`, a keychain belonging to an unrelated project. A
key in a **locked** keychain fails codesign no matter how many times the ACL is
re-asserted, because the ACL is not the problem.
*Diagnose in one command* — this is the question to ask the moment #15's fix doesn't take:
```bash
for kc in ~/Library/Keychains/*.keychain-db; do
  echo "$kc -> $(security find-identity -v -p codesigning "$kc" 2>/dev/null | grep -c <SHA1>)"
done
```
*Fix:* unlock **every** keychain, each with its own password file, and ACL each.
Do not assume one password covers them all.
```bash
for KC in login lfos-sign; do
  DB=~/Library/Keychains/$KC.keychain-db; [ -f "$DB" ] || continue
  case "$KC" in login) KCPW="$(cat ~/.config/keychain-pass)" ;;
                 *) PF=~/.config/$KC-pass; [ -f "$PF" ] && KCPW="$(cat "$PF")" || continue ;; esac
  security unlock-keychain -p "$KCPW" "$DB" 2>/dev/null || continue
  security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KCPW" "$DB" >/dev/null 2>&1 || true
done
```
A foreign keychain's password is *sometimes* findable — `lfos-sign`'s was hardcoded in
`~/code/lfos-mac/scripts/mac-build.sh`. Write it to `~/.config/<keychain>-pass` (mode 600)
so the workflow stays declarative.
⚠️ **Do not assume that still works.** Checked 2026-08-22: that script's `KEYCHAIN_PW` no
longer opens the current `lfos-sign.keychain-db` (the keychain was evidently recreated),
the Mac login password does not open it either, and no password file for it exists. When
the password is genuinely unavailable, go to gotcha 18 — do not keep hunting.

**17. Archive signs with a Development identity, and that is fine.**
*Signature:* the archive log reads `Signing Identity: "Apple Development…"` and
`Provisioning Profile: "iOS Team Provisioning Profile: <bundle>"`, not Distribution.
*Do not "fix" this.* With `signingStyle: automatic` + `method: app-store-connect`,
`-exportArchive` mints the distribution cert and App Store profile and **re-signs** at
export. Forcing distribution identity at archive time is a detour that adds an ASC API
CSR dance for nothing. Verified: build `1787412287` reached TestFlight `VALID` signed
this way.

**18. You cannot unlock it, because nobody holds the password.**
*Signature:* gotcha 16's diagnosis says the identity lives in a foreign keychain, and every
candidate password fails. The archive keeps dying on `errSecInternalComponent`.
*What does NOT work — verified, and each one costs a full release cycle to disprove:*
- `OTHER_CODE_SIGN_FLAGS="--keychain <login>"`. Xcode resolves the identity **before**
  codesign runs and passes `--sign <that SHA1>`; restricting codesign's search cannot undo
  a choice already made. Measured: identical failure, same SHA1.
- Re-asserting the ACL (`set-key-partition-list`) on a keychain you never opened.
*What works:* take the unopenable keychain out of the **search list** for the build, so
automatic signing falls through to an identity in a keychain you DO unlock.
```bash
ORIG=$(security list-keychains -d user | tr -d ' "' | tr '\n' ' ')
restore() { security list-keychains -d user -s $ORIG; }
trap restore EXIT
security list-keychains -d user -s ~/Library/Keychains/login.keychain-db
```
Confirm afterwards that the log reads `Signing Identity: "Apple Development: <you>"` — that
is the fall-through working, and per gotcha 17 a Development identity at archive is correct.

**19. The keychain search list is USER-GLOBAL, and a Mac can host several runners.**
*Why it bites:* one Mac often runs a runner service **per repo**
(`actions.runner.OWNER-repo-a.mac-x` and `…repo-b.mac-y` — check with
`launchctl list | grep actions.runner`). Those are independent: **their jobs can run at the
same time.** Anything gotcha 18 does to the search list — or any `set-key-partition-list` —
lands on the whole login session, so a second job archiving in that window sees a keychain
list it did not choose, and two interleaved save/restore pairs leave the developer's list
permanently wrong.
*Fix:* serialize the mutation and always restore it.
```bash
# macOS ships NO flock(1) — an flock line dies with exit 127 (`command not found`)
# and takes the step with it under `set -e`. Atomic mkdir is the portable mutex.
LOCK=/tmp/keychain-searchlist.lock
# A failed flock attempt leaves a regular FILE here (`exec 9>$LOCK` creates it).
# mkdir can never succeed against that, and a -d staleness check never sees it, so
# every later run burns the whole wait and proceeds unlocked. Clear it explicitly.
[ -e "$LOCK" ] && [ ! -d "$LOCK" ] && rm -f "$LOCK"
HELD=0
for _ in $(seq 1 600); do
  if mkdir "$LOCK" 2>/dev/null; then HELD=1; break; fi
  [ -d "$LOCK" ] && [ -z "$(find "$LOCK" -maxdepth 0 -mmin -30)" ] && rmdir "$LOCK"   # stale
  sleep 1
done
[ "$HELD" -eq 1 ] || echo "::warning::proceeding WITHOUT the lock"   # never block a release forever
# Release ONLY a lock this job owns, and never let the trap die on its first failure.
trap 'security list-keychains -d user -s $ORIG || true; [ "$HELD" -eq 1 ] && rmdir "$LOCK" 2>/dev/null; true' EXIT
```
*Tell-tale that you have this bug:* the job succeeds but takes ~10 minutes longer than it
used to, with no slow step in the timings — that is the lock loop spinning.
Prefer unlocking (gotcha 16) whenever the password exists — an unlock is process-local in
effect and needs no lock at all. Structure the step as *try to unlock; only if that fails,
take the lock and edit the search list*, so the day someone drops the password file in, the
global mutation stops happening on its own.

**20. Orphaned booted simulators wedge CoreSimulator.**
*Signature:* `Testing failed: Simulator device failed to install the application` /
`Placeholder did not exist for UUID …`, on a suite that passed an hour ago.
*Cause:* previous automated runs left simulators **Booted** with `Simulator.app` and Xcode
both closed; enough of them and installs start failing (and the machine's load average goes
with it).
*Fix:* `xcrun simctl shutdown all`. **Check first** that no human is using one —
`pgrep -x Xcode`, `pgrep -x Simulator` — because on a shared machine those are somebody's
open windows, not your leftovers. `xcrun simctl delete <udid>` your own throwaway sims at
the end of every job.

**Order matters:** 14 → 15 → 16 → 18 is the sequence a fresh app hits. Fix them in that
order; there is no shortcut, because each one is only reachable once the previous is
resolved. 19 applies the moment the Mac hosts more than one runner; 20 is independent.

### Reading the log without fooling yourself

Two traps that cost real cycles here:

- **GitHub echoes the whole `run:` script at the top of the step.** So grepping the log for
  your own `echo`/`::notice::` strings matches the *source of both branches of an `if`*, not
  what executed. `grep -c "took branch A"` returning 1 proves nothing. Grep for **effects**
  (`ARCHIVE SUCCEEDED`, `--sign <SHA1>`, `Signing Identity:`) or for the runner-timestamped
  output line, never for the script text.
- **`gh run view --log` on a failed iOS archive is ~5 MB of ScanDependencies noise.** The
  decisive line is the one immediately *before* `Command CodeSign failed`:
  ```bash
  gh run view <id> -R <repo> --log | awk -F'\t' '$2=="<step name>"' \
    | grep -B1 "Command CodeSign failed" | tail -3
  ```
  And to learn which identity was chosen — the question gotcha 16/18 turn on:
  ```bash
  gh run view <id> -R <repo> --log | grep -oE '\-\-sign [0-9A-F]{40}|Signing Identity: *"[^"]+"' | sort -u
  ```

### Before you touch a shared Mac at all

It is somebody's daily-driver laptop, not a build box. Prefer changes that live **in the
workflow** (unlock, ACL, scoped search-list edit under a lock, all restored on exit) over
changes to the machine's persistent state. If you do change persistent state, record the
exact prior value first and restore it — `security list-keychains` output before/after is
the whole audit trail, and "I restored it" without that capture is a guess. A wrong
"restore" is its own outage: reinstating a keychain into the search list is what re-broke
this pipeline after a green run.

## Copy-paste skeletons

⚠️ **These assume a MONOREPO** (`ios/` and `android/` folders in one repo). In a
single-platform repo — `coworking-ios`, `coworking-android`, where the app **is** the
repo root — delete every `working-directory:` and swap the `paths:` filter for
`paths-ignore: ["**/*.md"]`. Copied verbatim, `paths: ["ios/**"]` matches nothing and
**the workflow never fires**: no run, no red check, nothing to notice.

### iOS release → TestFlight (self-hosted Mac)

```yaml
name: Release iOS

# On push to main: build + upload to TestFlight on our OWN Mac (registered as a
# self-hosted runner labelled [self-hosted, macOS]) — no cloud macOS minutes. The
# runner runs as the Mac's login user, so it reuses the local signing assets:
# ~/.private_keys/AuthKey_<id>.p8, the login keychain (unlocked via
# ~/.config/keychain-pass), and ExportOptions.plist (destination: upload).
#
# If the Mac is asleep/offline the job queues until the runner reconnects.
on:
  push:
    branches: [main]
    paths:
      - "ios/**"
      - ".github/workflows/release-ios.yml"
  workflow_dispatch:

concurrency:
  group: release-ios-main
  cancel-in-progress: false          # never cancel a half-finished upload

permissions:
  contents: read

jobs:
  ios:
    name: Archive → TestFlight (self-hosted Mac)
    runs-on: [self-hosted, macOS]
    steps:
      - uses: actions/checkout@v4

      # Preflight. On a runner user who has never opened Xcode the archive dies with
      # "Agreeing to the Xcode/iOS license requires admin privileges", 8 minutes in.
      # Fix once by hand on the Mac: `sudo xcodebuild -license accept`.
      - name: Xcode preflight
        run: xcodebuild -version && xcode-select -p

      # Hermetic unit target only — seconds, no signing, no account, and no
      # shared simulator: the device is created and deleted here so it never
      # touches the Mac's own. UI tests that need a seeded backend do NOT
      # belong in the release gate (see "UI tests" below).
      - name: Unit tests
        working-directory: ios
        run: |
          set -euo pipefail
          /opt/homebrew/bin/xcodegen generate

          # No runtime given: simctl picks the newest one this device type
          # supports, so a dropped SDK doesn't silently pin us to a dead runtime.
          xcrun simctl delete ci-unit >/dev/null 2>&1 || true
          UDID=$(xcrun simctl create ci-unit "iPhone 16 Pro")
          trap 'xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true; xcrun simctl delete "$UDID" >/dev/null 2>&1 || true' EXIT

          # Boot it OURSELVES and wait: xcodebuild gives a cold device 60s and a
          # first boot on a busy Mac takes longer.
          xcrun simctl boot "$UDID"
          xcrun simctl bootstatus "$UDID" -b

          xcodebuild test \
            -project MyApp.xcodeproj -scheme MyApp \
            -destination "id=$UDID" \
            -only-testing:MyAppTests \
            CODE_SIGNING_ALLOWED=NO

      - name: Archive + upload to TestFlight
        working-directory: ios
        env:
          ASC_KEY_ID: ${{ secrets.ASC_KEY_ID }}
          ASC_ISSUER_ID: ${{ secrets.ASC_ISSUER_ID }}
        run: |
          set -euo pipefail
          # The two ASC key dirs are NOT interchangeable — a given key lives in one of
          # them (hyperglot's YU3W2WBQ2U in ~/.private_keys, coworking's 88TUBS56N8 in
          # ~/.appstoreconnect/private_keys). Take whichever holds this one.
          KEY=~/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8
          [ -f "$KEY" ] || KEY=~/.private_keys/AuthKey_${ASC_KEY_ID}.p8
          [ -f "$KEY" ] || { echo "::error::no .p8 for $ASC_KEY_ID on this Mac"; exit 1; }

          # The login keychain is locked for non-interactive sessions → codesign
          # fails until unlocked (password at ~/.config/keychain-pass, mode 600).
          security unlock-keychain -p "$(cat ~/.config/keychain-pass)" ~/Library/Keychains/login.keychain-db

          # Unlocking is not enough: a signing key whose partition list omits
          # codesign still fails the archive with `errSecInternalComponent`.
          # The ACL survives reboots but not every keychain reset — re-assert it
          # here; the call is idempotent.
          security set-key-partition-list -S apple-tool:,apple:,codesign: \
            -s -k "$(cat ~/.config/keychain-pass)" ~/Library/Keychains/login.keychain-db >/dev/null

          # Regenerate the Xcode project from project.yml (it is not committed).
          /opt/homebrew/bin/xcodegen generate

          # CFBundleVersion must strictly increase across uploads; epoch is
          # unique and monotonic. MARKETING_VERSION stays on its human track.
          NEXT=$(date +%s)
          # If project.yml does NOT declare CFBundleVersion: "$(CURRENT_PROJECT_VERSION)",
          # the build-setting override below is a NO-OP — stamp the plist instead:
          # /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEXT" Generated/Info.plist

          xcodebuild archive \
            -project MyApp.xcodeproj -scheme MyApp \
            -destination 'generic/platform=iOS' -archivePath /tmp/MyApp.xcarchive \
            -allowProvisioningUpdates \
            -authenticationKeyPath "$KEY" \
            -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
            CURRENT_PROJECT_VERSION="$NEXT"

          # ExportOptions.plist has destination: upload → this delivers to ASC.
          xcodebuild -exportArchive \
            -archivePath /tmp/MyApp.xcarchive \
            -exportOptionsPlist ExportOptions.plist -allowProvisioningUpdates \
            -authenticationKeyPath "$KEY" \
            -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID"

          echo "Uploaded build $NEXT to TestFlight (processing happens async at ASC)."

          # Only needed when the internal group has hasAccessToAllBuilds:false.
          # Non-fatal: a transient ASC error must not fail a successful upload.
          # `node` is nvm-managed and not on a non-login PATH (gotcha 3).
          NODE="$(command -v node || true)"
          [ -n "$NODE" ] || NODE="$(ls -d "$HOME"/.nvm/versions/node/*/bin/node | tail -1)"
          ASC_KEY_ID="$ASC_KEY_ID" ASC_ISSUER_ID="$ASC_ISSUER_ID" ASC_KEY_PATH="$KEY" \
            "$NODE" ci_scripts/attach-build-to-testflight.mjs "$NEXT" \
            || echo "::warning::attach failed; build $NEXT uploaded but not added to the internal group"

      # dSYMs only. With `destination: upload` no .ipa is ever written to disk, and
      # nothing here writes an xcodebuild log — add `-resultBundlePath` or
      # `| tee /tmp/archive.log` above first if you want those paths to be real.
      - name: Artifacts (dSYMs)
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: ios-build
          path: /tmp/MyApp.xcarchive/**/*.dSYM
          if-no-files-found: warn
```

`-allowProvisioningUpdates` + the ASC key is what mints the distribution cert and
profile on demand — the Mac does **not** need the identity pre-installed for a new
app. Expect the *first* archive for a new bundle id to be where any ASC-permission
problem surfaces.

**Baking config into the binary** (e.g. pointing at prod Supabase) — regenerate the
source file before `xcodegen generate`:

```yaml
      - name: Point app at prod backend
        working-directory: ios
        env:
          SUPABASE_URL: ${{ vars.SUPABASE_URL }}
          SUPABASE_ANON_KEY: ${{ vars.SUPABASE_ANON_KEY }}
        run: |
          cat > Sources/SupabaseConfig.swift <<EOF
          enum SupabaseConfig {
              static let url = "$SUPABASE_URL"
              static let anonKey = "$SUPABASE_ANON_KEY"
          }
          EOF
```
The anon key is a **public client key** → repo `vars`, not `secrets`. This dirties the
checkout; harmless on a runner, must never be committed back. Order matters: run the
unit tests **before** this step if they need a local/seeded backend.

### Android release → TestApp.io (self-hosted Linux)

```yaml
name: Release Android

on:
  push:
    branches: [main]
    paths:
      - "android/**"
      - ".github/workflows/release-android.yml"
  workflow_dispatch:

concurrency:
  group: release-android-main
  cancel-in-progress: false

permissions:
  contents: read

jobs:
  android:
    name: Signed build → TestApp.io
    runs-on: [self-hosted, Linux, X64]
    # Runner `run:` steps use NON-LOGIN bash — ~/.zshrc and ~/.profile never
    # apply, and the box default `java` may be a different major version.
    # Pin the JDK **and the SDK** explicitly: `local.properties` is gitignored so it
    # does not exist in the runner workspace, and a freshly registered runner instance
    # has an empty `.env` — inherit nothing and Gradle fails "SDK location not found".
    # These paths are specific to this box/user; change them for another host.
    env:
      JAVA_HOME: /home/justin/android-tooling/jdk
      ANDROID_HOME: /home/justin/android-tooling/sdk
      ANDROID_SDK_ROOT: /home/justin/android-tooling/sdk
    steps:
      - uses: actions/checkout@v4
      # NOTE: no `actions/setup-java` + no `cache: gradle`. On a persistent
      # runner ~/.gradle and the Gradle daemon already survive between jobs;
      # the cache round-trip is pure latency and one more failure mode.
      # (On ubuntu-latest, do the opposite: setup-java@v4 + cache: gradle.)

      - name: Restore release keystore + key.properties
        env:
          KEYSTORE_B64: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
          STORE_PW: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
          KEY_ALIAS: ${{ secrets.ANDROID_KEY_ALIAS }}
          KEY_PW: ${{ secrets.ANDROID_KEY_PASSWORD }}
        run: |
          echo "$KEYSTORE_B64" | base64 -d > app/release.keystore
          cat > key.properties <<EOF
          storeFile=app/release.keystore
          storePassword=$STORE_PW
          keyAlias=$KEY_ALIAS
          keyPassword=$KEY_PW
          EOF

      - name: Unit tests
        run: ./gradlew :app:testDebugUnitTest

      - name: Build signed App Bundle + APK
        # versionCode = epoch → strictly increasing across uploads (Play requires it).
        # ⚠️ Match the -P names to what build.gradle.kts actually reads (coworking:
        # VERSION_CODE/SUPABASE_URL/SUPABASE_ANON_KEY; hyperglot: versionCode). A
        # mismatched -P is silently IGNORED — every upload then collides on the same
        # default versionCode.
        run: |
          ./gradlew bundleRelease assembleRelease \
            -PSUPABASE_URL="${{ vars.SUPABASE_URL }}" \
            -PSUPABASE_ANON_KEY="${{ vars.SUPABASE_ANON_KEY }}" \
            -PVERSION_CODE="$(date +%s)"

      - name: Release notes (capped commit subject)
        id: notes
        # git_release_notes uses the FULL commit message; TestApp.io rejects >1200 chars.
        run: echo "text=Production build from main — $(git log -1 --pretty=%s | cut -c1-180)" >> "$GITHUB_OUTPUT"

      - name: Distribute APK to TestApp.io
        continue-on-error: true    # distribution hiccup must not red a good build
        uses: testappio/github-action@v5
        with:
          api_token: ${{ secrets.TESTAPPIO_API_TOKEN }}
          app_id: ${{ secrets.TESTAPPIO_APP_ID }}
          file: app/build/outputs/apk/release/app-release.apk
          release_notes: ${{ steps.notes.outputs.text }}
          git_release_notes: false
          include_git_commit_id: true
          notify: true

      - name: Upload App Bundle (.aab) artifact
        uses: actions/upload-artifact@v4
        with:
          name: app-release-aab
          path: app/build/outputs/bundle/release/app-release.aab

      # GOTCHA 13 — mandatory on a persistent runner. Without this the next PR
      # build in this same workspace signs with the PRODUCTION key.
      - name: Scrub signing material
        if: always()
        run: rm -f app/release.keystore key.properties
```

Optional Google Play promotion, gated so the workflow stays green before the
developer account exists:

```yaml
      - name: Check Play credentials
        id: playcheck
        env:
          SA: ${{ secrets.PLAY_SERVICE_ACCOUNT_JSON }}
        run: |
          if [ -n "$SA" ]; then echo "ready=true" >> "$GITHUB_OUTPUT"; else echo "ready=false" >> "$GITHUB_OUTPUT"; fi

      - name: Upload AAB to Google Play (internal track)
        if: ${{ steps.playcheck.outputs.ready == 'true' }}
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.PLAY_SERVICE_ACCOUNT_JSON }}
          packageName: com.example.app
          releaseFiles: app/build/outputs/bundle/release/app-release.aab
          track: internal
          status: completed
```

Non-GitHub CI can still ship to TestApp.io via its CLI:
`curl -Ls https://github.com/testappio/cli/releases/latest/download/install | bash`
then `ta-cli publish --api_token=… --app_id=… --release=ios --ipa=…`.

### PR gate (GitHub-hosted, on purpose)

```yaml
name: PR checks

# Fast pre-merge gate on a free runner: the app must compile and its unit tests
# must pass. iOS is compiled by the self-hosted Mac on release; gating PRs on it
# would block whenever the Mac is asleep. This job must never touch a release
# keystore or a self-hosted workspace.
on:
  pull_request:
    branches: [main]
    types: [opened, synchronize, reopened]

concurrency:
  group: pr-${{ github.event.pull_request.number }}
  cancel-in-progress: true      # inverse of the release lane: supersede freely

permissions:
  contents: read

jobs:
  android-compile:
    name: Android compiles + unit tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: "17"
          cache: gradle
      - run: ./gradlew :app:assembleDebug
      - run: ./gradlew :app:testDebugUnitTest
```

## Failure modes — how to tell them apart

**`errSecInternalComponent` at CodeSign — three different causes, same string.**
Work through them in this order; each is only reachable once the previous is fixed:
1. Keychain locked → unlock it (gotcha 1).
2. Key's partition list omits `codesign` → `set-key-partition-list` (gotcha 2).
3. Key was minted mid-archive, after that call ran → retry with a re-assert (gotcha 15).
4. Key is in a *different* keychain you never unlocked → unlock them all (gotcha 16).
If a fix "didn't work", suspect the next cause down rather than the one you just applied
— 16 is indistinguishable from 15 by log output alone. Settle it by asking which
keychain actually holds the SHA1 from the failing `codesign` line.


| Symptom | Cause | Fix |
|---|---|---|
| Job sits in **Queued**, no log, forever | Mac asleep / runner offline; **or the Mac rebooted and nobody logged in** (the service is a LaunchAgent, not a daemon); **or no online runner carries the label `runs-on` asks for** — including a runner registered into the wrong `Default` group | Wake the Mac / log in (it drains automatically). Confirm with `gh api /repos/OWNER/REPO/actions/runners --jq '.runners[]\|{name,status,labels:[.labels[].name]}'` — `offline` = machine; `total_count: 0` = not granted to this repo; online-but-missing-the-label = add it live with `POST .../runners/<id>/labels`. |
| `codesign` / archive fails, no useful detail; works when you ssh in and build by hand | **Login keychain locked** for the non-interactive job | Gotcha 1 — `security unlock-keychain`. |
| **`errSecInternalComponent`** during archive, *after tests passed* | Key **partition list** omits `codesign` | Gotcha 2 — `security set-key-partition-list -S apple-tool:,apple:,codesign:`. Not a code problem; nothing in the app changed. |
| Upload rejected, **HTTP 409** / "bundle version already used" | `CFBundleVersion` didn't increase — usually the override never reached the plist | Gotchas 4 / 4b. Check `Generated/Info.plist` after `xcodegen generate`: if it literally says `1`, the build-setting override is a no-op. |
| `"Failed to prepare device … Timed out trying to boot simulator"` | **Cold simulator** — `xcodebuild`'s 60s allowance on a busy Mac | Gotcha 8 — `simctl boot` + `bootstatus -b` yourself first. |
| `"Unable to find a device"` (exit 70) | Runtime/device-type mismatch — `OS:latest` resolved to a version with no such simulator | Gotcha 9 — don't pin a runtime in CI. |
| Job green, **nothing in TestFlight at all** | `ExportOptions.plist` missing `destination: upload` — you exported an `.ipa` to disk | Gotcha 5. |
| Build **visible in ASC**, invisible to testers | Not attached to the internal group (`hasAccessToAllBuilds: false`) | Gotcha 7 — run the attach script, or flip the group to auto-include. |
| Job green, build **disappears hours later**; an "Action needed" email arrives | Apple **async-rejected** after accepting (ITMS-90683 etc.) — email-only, never surfaced in CI | Gotcha 6. Poll ASC after the run; check Gmail `from:apple.com`. Not a CI bug. |
| A **PR** build came out release-signed | Persistent runner: leftover `key.properties` from the previous release job | Gotcha 13 — `if: always()` scrub, and keep PR gates on `ubuntu-latest`. |
| `"Agreeing to the Xcode/iOS license requires admin privileges"` | Runner user has never opened Xcode / Xcode was upgraded | `ssh mac 'sudo xcodebuild -license accept'` once; keep the `xcodebuild -version && xcode-select -p` preflight so it fails in 3s, not 8 min. |
| Gradle: `"SDK location not found"` | Runner `.env` has no `ANDROID_HOME` (fresh instance) and `local.properties` is gitignored | Pin `ANDROID_HOME`/`ANDROID_SDK_ROOT` in the job `env:` — do not rely on the runner's `.env`. |
| Android build uses the wrong Java / weird AGP error only in CI | Runner steps are **non-login** bash; `~/.zshrc` never runs, box default `java` wins | Pin `JAVA_HOME` at job level (or `actions/setup-java`). Also check the runner's `.env` `ANDROID_HOME` — `local.properties` is gitignored and won't exist on the runner. |

### Verify an upload (green is not proof — gotcha 6)

`gh run watch` only proves the *job* finished. Poll ASC for the CFBundleVersion the job
echoed. A dependency-free CLI already exists — copy it and set the bundle id:

```bash
cp ~/code/hyperglot-workspace/hyperglot-book-reader/.claude/skills/testflight-release/scripts/asc.mjs /tmp/asc.mjs
sed -i 's/com\.hyperglot\.book-reader/<your.bundle.id>/' /tmp/asc.mjs

source ~/.zshrc      # LASER_FOCUSED_ASC_KEY_ID / _ISSUER_ID / _KEY_PATH
ASC_KEY_ID=$LASER_FOCUSED_ASC_KEY_ID ASC_ISSUER_ID=$LASER_FOCUSED_ASC_ISSUER_ID \
  ASC_KEY_PATH=$LASER_FOCUSED_ASC_KEY_PATH node /tmp/asc.mjs builds 3
# 1781525233   VALID   2026-06-15T05:12:40-07:00      <- verified 2026-08-22, coworking
```

`status <version>` gives one build's `processingState`; `verify <version>` exits 1
unless it is VALID **and** attached to an internal group — that is the gate that
catches an Apple async-rejection. A build that never appears was accepted-then-rejected
(email only).

## Two worked references

**1. `hyperglot-book-reader` — the original.**
`/home/justin/code/hyperglot-workspace/hyperglot-book-reader/.github/workflows/`
- `release-ios.yml` — self-hosted Mac (`mac-hyperglot`, repo-scoped, LaunchAgent
  `actions.runner.LaserFocused-ee-hyperglot-book-reader.mac-hyperglot.plist`),
  own throwaway simulator running `PaymentSurfaceTests` + `TaskSetWireTests`
  before the archive, then archive → export(upload) → attach-to-group.
  `project.yml` declares `CFBundleVersion: "$(CURRENT_PROJECT_VERSION)"`, so the
  plain build-setting override works. Team `6FKN6D7964`, ASC key `YU3W2WBQ2U` at
  `~/.private_keys/`. `ios/codemagic.yaml` is kept only as a cold fallback.
- `release-android.yml` + `pr.yml` — both on `ubuntu-latest`, deliberately.
  Read `pr.yml`'s header comment; it is the whole argument for the split.

**2. `coworking-ios` / `coworking-android` — the second application.**
Workspace `/home/justin/code/coworking-mng-not-shit/{ios,android}`.
- Replaces `ios/codemagic.yaml` (workflow `ios-testflight`, `mac_mini_m2`) and its
  manual `POST https://api.codemagic.io/builds` trigger — Codemagic never fired on
  push, so `on: push: branches:[main]` is a genuine upgrade, not a port.
  **As built (2026-08-22):** `coworking-ios/.github/workflows/release-ios.yml` +
  `ExportOptions.plist` + `ci_scripts/attach-build-to-testflight.mjs` exist;
  `codemagic.yaml` is kept as a cold fallback with its `triggering:` block commented
  out, so the two pipelines cannot race for a build number.
- Project `Cowork.xcodeproj`, scheme `Cowork`, bundle `ee.laserfocused.cowork`,
  ASC app `6776261026` ("Commons"), team `6FKN6D7964`, ASC key **`88TUBS56N8`** in
  `~/.appstoreconnect/private_keys/` (built from `templates/ExportOptions.plist`).
- **Hits gotcha 4b:** `project.yml` does not declare `CFBundleVersion`, so keep
  Codemagic's proven `PlistBuddy` epoch stamp on `Generated/Info.plist`.
- Internal group `"Testers"` has `hasAccessToAllBuilds: true` → the attach script is
  **not required** (gotcha 7 already satisfied). It is shipped anyway as insurance for
  the day that flag is flipped or a second group appears, and its `::warning::`-only
  failure mode costs nothing.
- Release gate = `CoworkTests` (`BookingGridTests`, `PublicEventDetailTests`) only.
  `CoworkUITests`/`CalendarGestureUITests` stay OUT: they need seeded demo data, and
  the release build has just repointed `SupabaseConfig` at **prod** — they'd fail, or
  write to production. They also need both an 18.x and a 26.x simulator, which
  contradicts gotcha 9. Keep them `workflow_dispatch`-only.
- Android: the Linux runner is **already org-level** (`hetzner-prod`, agentId 62,
  `gitHubUrl: https://github.com/LaserFocused-ee`, `poolName: hyperglot-prod`) —
  `hyperglot-prod` is a runner *group* (id 5, `visibility: selected`), not a scope.
  The Mac's `~/actions-runner/.runner` by contrast has
  `gitHubUrl: .../LaserFocused-ee/hyperglot-book-reader` → genuinely repo-scoped. Granting `coworking-android` is one `PUT .../runner-groups/5/repositories/<id>`;
  no reinstall. Gotcha 13 becomes mandatory the moment it moves.
- Repo state: `coworking-ios` still has **zero** secrets and variables —
  `ASC_KEY_ID`, `ASC_ISSUER_ID`, `SUPABASE_URL`, `SUPABASE_ANON_KEY` must be created
  before the first push, or run 1 dies at the config step. `coworking-android` already
  has all 6 secrets + 2 vars and they keep working unchanged on self-hosted. Its
  `release.yml` deliberately stays on `ubuntu-latest` with the self-hosted lane
  commented out until a runner carries `coworking-android` — see the "flip" step in
  its `RUNNER-SETUP.md`.
- The Mac runner is repo-scoped to `hyperglot-book-reader` and **cannot** serve
  coworking — second instance or org-level registration required.

## Docs that go stale when you land this

Grep the repo before you finish; a Codemagic reference left behind is a trap for the
next session. Grep for the **string**, not the line number (these move). In coworking
that was: `ios/CLAUDE.md` — `"Codemagic does NOT auto-fire on push"` (the `POST /builds`
recipe; its `"does NOT wait for Apple's processing"` clause is **still true** and must
survive) and `"not Codemagic secrets"` → "not CI secrets"; `ios/project.yml` —
`"Codemagic-fetched provisioning profile"`; `android/CLAUDE.md` — `"CI builds on GitHub
runners"` and the `JAVA_HOME=` / `local.properties` notes (the prefix stops being
hygiene and becomes load-bearing); plus workspace `docs/test-plans/mobile-apps.md` and
`docs/remediation-*/`.

## When NOT to use this

- **No Apple work in the repo.** If there's no iOS target, there's no macOS
  requirement, and the entire argument collapses — `ubuntu-latest` is free, ephemeral,
  and infinitely parallel. Self-hosted Android is a *speed* optimisation, not a cost
  one; take it only when the warm Gradle daemon actually matters to you.
- **Anyone needs builds while the Mac is off.** A laptop that travels, a team in
  another timezone, an on-call release path — a queued job is not an outage but it is
  not a build either. Pay for cloud macOS, or dedicate an always-on Mac mini.
- **The runner is already contended.** One shared runner is a serialization point.
  This box's `hetzner-prod` backs 24 hyperglot services plus `speech-engine`; a 3–8
  minute mobile build will sit in front of a production deploy or vice versa. Weigh
  that before adding a lane.
- **PR gates, always.** Never move a PR check onto the Mac. It must not queue behind
  a sleeping machine, and it must not be able to see a release keystore.
- **You need multi-version/matrix simulator runs, or heavy parallel CI.** One Mac is
  one Mac. Matrix jobs will serialize on it.

## Templates

- `templates/ExportOptions.plist` — the `destination: upload` file (gotcha 5).
- `templates/attach-build-to-testflight.mjs` — dependency-free ASC attach script
  (gotcha 7). Set `BUNDLE_ID`. Skip entirely if the group auto-includes.

*(The previous Flutter/Cloudflare-Pages/Supabase-preview templates are superseded and
archived under `~/.claude/backups/skills-removed-*/mobile-cicd-pipeline-templates/`.)*
