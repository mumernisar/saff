# Saff documentation

| File | Answers |
|---|---|
| `PRODUCT.md` | What the app does, every rule and number |
| `ARCHITECTURE.md` | How it's built: layers, modules, state, offline, server split, decision log |
| `REPOSITORY.md` | Folder layout, packages, dependency rules, tooling, CI, conventions |
| `ERRORS.md` | Error taxonomy, failure model, mappers, retries, logging, user messages |
| `DATA_MODEL.md` | Firestore collections, local database, ids, time, migrations |
| `BACKEND.md` | Cloud Functions: triggers, tasks, callables, push messages, content gateway, imports |
| `ALARM.md` | The native alarm module and its device checklist |
| `CONTENT.md` | Card packs, placeholders, lessons and paths, learning schedule, Anki import |
| `SECURITY.md` | Rules, App Check, secrets, personal data, deletion |
| `TESTING.md` | Test kinds per layer, fixtures, emulators, device matrix, CI gates |
| `STAGES.md` | The build plan, stage by stage, with exit criteria |
| `OPEN_QUESTIONS.md` | Questions waiting for the owner, and decisions already made |
| `DEMO.md` | Two-phone demo on physical phones with the emulators: setup and script |
| `DEV_RELAXATIONS.md` | Rules relaxed for development and demos, each with how to revert it for prod |
| `stages/` | One file per completed stage: starting point, what was done, why |
| `design/` | Exported mockups (source of truth for visuals) |

**Terms used everywhere**

| Term | Meaning |
|---|---|
| saff | A group of 2–10 people who wake together (the app's core object); a user can be in several |
| pair / group | A saff of exactly 2 / of 3 or more (some rules differ) |
| participant | A member an alarm rings for (in a pair: both; in a group: those who accepted it) |
| member | A user in a saff |
| alarm | A recurring wake time agreed by all members of a saff |
| occurrence | One specific morning of an alarm (alarm + date) |
| round | The locked set of content for one occurrence (mode + cards or game seed) |
| night lock | The moment, 60 min before an occurrence, when its round is assembled and frozen |
| result | One member's raw play data for a round |
| reveal | The moment results become visible to all members |
| pack | A collection of cards (official, surah, community, or imported) |
| planted card | A card a member of a pair writes at night for the other |
| nudge | "Ring again": a member re-triggers another member's alarm |
| Saff Plus | The optional subscription: bigger groups for saffs you own, unlimited saffs, imports, full stats history, cosmetics |
| entitlement | A user's plan and limits, written only by the server |

Anything marked **OPEN (Q-n)** is waiting for the owner's answer (`OPEN_QUESTIONS.md`). Don't implement it until answered.
