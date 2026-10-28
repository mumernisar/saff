# CLAUDE.md

You are implementing **Saff**, an alarm app where a small group (a *saff*) wakes up together into a
short duel and a conversation. This file tells you how to work in this repository. Read it fully
before every session.

## 1. Read before writing code

Read in this order the first time, then whichever files your stage touches:

1. `docs/README.md`: map of the documentation
2. `docs/PRODUCT.md`: what the app does (behaviour is decided there, not in code)
3. `docs/ARCHITECTURE.md`: how the app is built, and why
4. `docs/REPOSITORY.md`: where code lives and which package may import which
5. `docs/ERRORS.md`: the only accepted way to handle errors
6. `docs/STAGES.md`: the build plan; find the current stage
7. The stage-specific docs it lists (`ALARM.md`, `BACKEND.md`, `DATA_MODEL.md`, `CONTENT.md`,
   `SECURITY.md`, `TESTING.md`)
8. `docs/design/`: the mockups. Screens must match them.

If two documents disagree, or a document disagrees with the mockups, **stop and ask**. Do not pick one.
Rules marked **OPEN (Q-n)** are undecided: don't implement them; build around them and ask the owner
when your stage reaches one.

## 2. The stage protocol (mandatory)

The project is built in stages (`docs/STAGES.md`). Never work outside the current stage.

**At the start of a stage:**
1. Copy `docs/stages/_TEMPLATE.md` to `docs/stages/NN-short-name.md`.
2. Fill in **Starting point**: what exists right now (packages, screens, functions, tests, known
   issues), verified by reading the code, not by trusting earlier notes.
3. Fill in **Plan**: what this stage will build, in the order you will build it, mapped to the
   stage's exit criteria.
4. Show the plan to the user and wait for approval.

**During the stage:**
- Work on a branch named `stage/NN-short-name`.
- Commit in small steps with Conventional Commits (`feat(alarm): ...`, `fix(chat): ...`, `test(...)`, `docs(...)`).
- When you make a decision the docs don't cover, record it in the stage file under **Decisions**,
  with the alternatives you considered and why you chose this one.

**At the end of a stage:**
1. Every exit criterion in `STAGES.md` is met and demonstrated (tests, screenshots, device notes).
2. `melos run ci` passes locally (analyze, format check, tests, rules tests, function tests).
3. Fill in the stage file: **What was done**, **Decisions** (and why), **Deviations from the docs**,
   **Known issues**, **Follow-ups for later stages**.
4. Update every doc your stage changed (data model, errors catalog, architecture). Docs must describe
   the code as it is.
5. Ask the user to review. Do not start the next stage until they approve.

## 3. Non-negotiable rules

**Architecture**
- Views never touch services, Firebase, Drift or platform channels. View → ViewModel → Repository → Service.
- Features never import other features. Shared things go in a package or a repository.
- Packages never import the app. Respect the dependency graph in `REPOSITORY.md`; CI enforces it.
- The server is authoritative for rounds, grading, reveals, stats, streaks and learning schedules.
  The client never computes another member's result.

**Errors**
- Repositories return `Result<T>`; they never throw across the boundary.
- Every caught exception is converted by a `FailureMapper` into an `AppFailure` with a catalog code.
- Never show `e.toString()` to a user. Every failure has a user message key.
- Never catch `Error` (bugs). Let them reach the global handlers.
- New failure codes go into `contracts/errors.json` first, then both Dart and TypeScript.

**The alarm**
- Nothing in the ring path may depend on the network, Firebase, or the Flutter engine starting.
- Any change under `packages/saff_alarm/` requires the device checklist in `docs/ALARM.md` §9.

**Content**
- Never hard-code Quran or hadith text. Text comes from the content gateway and is cached.
- Never invent card content. Cards come from packs, imports, or users.

**Dependencies**
- Do not add a package dependency without recording it in the stage file (why, alternatives,
  maintenance status, licence). Prefer the packages already chosen in `ARCHITECTURE.md` §10.
- No experimental APIs (e.g. Riverpod's `experimental/` imports) in production code.

**Code**
- Never edit generated files (`*.g.dart`, `*.freezed.dart`, `*.drift.dart`, Pigeon output). Change the
  source and run `melos run generate`.
- Every public class and method in packages has a doc comment.
- No `print`. Use the `Log` interface.
- No secrets in the repo. Use `--dart-define-from-file` (gitignored) and Secret Manager on the server.
- Every dev-only relaxation of a documented rule is listed in `docs/DEV_RELAXATIONS.md` before it is
  built, with its gate and how to revert it for prod.

**Tests**
- Every bug fix starts with a failing test.
- Coverage gates and required test kinds per layer are in `docs/TESTING.md`.

## 4. Commands

```
melos bootstrap          # install everything (or: flutter pub get at the root)
melos run generate       # build_runner + pigeon for all packages
melos run analyze        # analyzer + import-boundary check
melos run test           # all Dart tests
melos run ci             # everything CI runs
cd functions && npm test # Cloud Functions tests (uses emulators)
npm run test:rules       # Firestore and Storage security rules tests
flutter run --flavor dev -t lib/main_dev.dart --dart-define-from-file=env/dev.json
```

## 5. When to ask the user

- A document is missing a rule you need, or two rules conflict.
- A mockup shows something the docs don't describe (or the reverse).
- A platform or policy limitation blocks a documented behaviour.
- You would need to change a decision recorded in `ARCHITECTURE.md`.

Ask one clear question with your recommended answer. Don't guess on product behaviour.
