# Open questions and decisions

## Open (waiting for the owner)

Docs mark these as **OPEN (Q-n)**. Don't implement them until answered.

| # | Question | Needed by |
|---|---|---|
| Q-8 | Which English and which Urdu Quran translation (owner is registering with Quran Foundation; pick from their licensed list) | Stage 5 |

## Decided

| Decision | Date |
|---|---|
| Saff size 2–10 (free up to 4, owner's Plus up to 10) | 2026-10-25 |
| A user can be in several saffs (mockups include a switcher) | 2026-10-25 |
| Planted cards only in pairs, 2 per member per night, never scored | 2026-10-28 |
| Pairs: alarm consent mandatory. Groups: alarms are opt-in; they ring only for members who accepted | 2026-10-25 |
| Group alarms start at 2 participants and keep ringing if only 1 remains (solo morning) | 2026-10-28 |
| Changing or deleting a group alarm needs every current participant to accept | 2026-10-28 |
| Alarm time is in the creator's timezone; everyone rings at the same moment | 2026-10-28 |
| Owner role: rename, regenerate invite, remove members; in groups the owner sets mode schedule and card mix | 2026-10-28 |
| Learning is individual; reviews happen both in the morning (Learning Duel, own cards, ranked by accuracy) and in the Learn tab | 2026-10-28 |
| Account deletion: messages are not rewritten; the app shows "Deleted user" | 2026-10-28 |
| Region `us-central1` for everything (all free allowances apply) | 2026-10-28 |
| UI language English for v1 | 2026-10-28 |
| Android only for now | 2026-10-25 |
| Flutter is a hard requirement for the client; the framework is not open for change (`ARCHITECTURE.md` D1) | 2026-10-28 |
| Stay on Firebase within free allowances; no Render/Heroku | 2026-10-25 |
| New mode: Selfie (every participant posts a selfie; revealed together; unranked) | 2026-10-28 |
| Selfies deleted from the server 24 h after the reveal; members can save them to their gallery | 2026-10-28 |
| No two alarms a user participates in may ring within 30 minutes of each other (across saffs) | 2026-10-28 |
| Mockups exported into `docs/design/` before Stage 2 | 2026-10-25 |
| Business model: Saff Plus (owner pays for groups up to 10; free groups up to 4; free users in up to 2 saffs, Plus unlimited with a 25 abuse cap; imports, full stats history and cosmetics are Plus); Quran and learning content always free; no ads; members never removed when Plus lapses | 2026-10-28 |
