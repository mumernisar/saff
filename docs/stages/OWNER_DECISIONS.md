# Decisions and actions waiting for the owner

Collected while building without the owner present (2026-10-29). Nothing here blocked progress; each item
has the default I used. Reverse a default by telling me.

## Needs your action (credentials / accounts / devices)
1. **Google sign-in**: needs the debug and release SHA-1 fingerprints added to the Firebase Android apps
   (`saff-dev-d9605`, `saff-prod`) and the Google provider enabled in Auth. Until then, dev builds sign in as seeded test users.
2. **Real FCM pushes from the emulator** (`roundLocked`, `nudge`; `DEV_RELAXATIONS.md` R-5): create a service-account key for
   `saff-dev-d9605` (role: Firebase Cloud Messaging API Admin) and point `GOOGLE_APPLICATION_CREDENTIALS` at it in
   `functions/.env.local`. Without it, pushes are logged as failed and nudges cannot ring a killed phone.
3. **Quran Foundation credentials** (Q-8, also which English and Urdu translation): the content gateway and every
   surah/learning card need them. Until then only the 20 core-pack cards without placeholders play.
4. **Blaze plan for `saff-dev`** (Stage 5): needed for deployed Functions, Cloud Tasks and the billing cap.
5. **More phones / OEMs** for the alarm device checklist (`ALARM.md` §9), a second phone for two-device demos.
6. **Play Console** (Stage 13/14): subscription products, declarations, service account for purchase verification.

## Decisions I made that the docs did not cover (change on request)
- **Scope/timing**: sweeper runs every minute (Cloud Scheduler) and a dev ticker (`tools/demo/ticker.sh`, R-11) instead of Cloud Tasks; occurrences planned 7 days ahead, not 48 h.
- **Proposals applied inside `voteProposal`/`createProposal`** (no `onVoteWritten` trigger); owner rename via new `renameSaff` callable (resolves D-6).
- **Docs vs mockups**: PRODUCT.md wins on behaviour (hold to start, 8 cards, per-person learning), mockups on look.
- **No codegen** (freezed/riverpod_generator/Drift): hand-written models, Firestore offline cache instead of Drift `locked_rounds`.
- **Content**: only core-pack cards without gateway placeholders are playable; surah/learning content waits for Quran Foundation credentials.
- **Planting**: server `plantCard`, bonus cards in rounds, the "Leave a card" screen (quiz, multiple choice, ask-me) and the review are built; ask-me grading by the planter and the recipient teaser are NOT built; not yet exercised on a device.
- **Not built**: Word/Climber/Rapid Roll/Selfie modes, Learning track, Anki import, Plus billing, account deletion, Google sign-in, packs by link, release pipeline, Drift, tests beyond the emulator smoke (`tools/demo/smoke.mjs`, `peer.mjs`).
- **Climber** is built (touch-half steering per mockup, seeded platforms, server grades by metres, shared ranks). It uses plain Flutter painting, not Flame, to avoid a dependency; Rapid Roll, Word and Selfie are not built. **Word mode needs a word list source** (no content may be invented): please choose one.
- Mode choice is seeded per occurrence (Card Duel 2/3, Climber 1/3) because only two modes exist; owner mode schedules beyond "one mode" are not wired.
- Learn tab shows an honest empty state until the content gateway has credentials.
