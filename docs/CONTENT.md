# Content

## 1. Sources of cards

| Source | Where it lives | Who can use it |
|---|---|---|
| Official packs (`core-*`) | Packs repo → GitHub Pages `dist/` | Everyone |
| Surah packs (learning track) | Packs repo, with `lessons.json` and `path.json` | Everyone |
| Community packs | Packs repo `packs/community/` | Everyone (labelled Community) |
| Pack by link | Any URL serving pack JSON in the packs format | The saff that added it |
| Anki import | `saffs/{id}/packs/{packId}` in Firestore | The saff that imported it |
| Planted cards | Round bonus cards (pairs only) | That round only |

The packs repository is separate (`FORMAT.md` and `docs/surah-learning-track.md` there are the
format reference). The app consumes the built output only.

## 2. Pack consumption

- `PackService` fetches `index.json` from the packs base URL (config), compares `sha256` per pack with
  Drift, downloads changed pack JSON, verifies the checksum (`PACK_CHECKSUM_MISMATCH` → keep old,
  retry later), and stores packs, cards, lessons and paths in Drift.
- Supported `format_version`s are listed in the app; an unknown major version → skip the pack and
  show "Update Saff to use this pack" (`PACK_VERSION_UNSUPPORTED`).
- The server reads the same `index.json` for round assembly (cached per version).
- Pack by link: the client validates the JSON shape, the server re-validates and copies it into
  `saffs/{id}/packs/` (so round assembly never fetches arbitrary URLs during a lock).

## 3. Card model (domain)

```dart
sealed class CardContent {
  CardId id; Category category; String? topic; Difficulty difficulty;
  String question; String answer; String explanation; String? talk; String? source;
  AyahRange? covers; List<String> tags;
}
final class ChoiceCard extends CardContent { List<String> options; }
final class TypedCard  extends CardContent { List<String> accept; }
final class SelfCard   extends CardContent { }             // imported long answers
final class AskMeCard  extends CardContent { String authorId; }  // planted
```
`CardViewFactory` picks the widget: choice rows, typed input, self-reveal, and the Arabic-specific
layouts when the question contains `{{arabic}}` or `{{blank}}` placeholders.

**Packs format addition (to make in the packs repo, format v2):** allow cards with neither `options`
nor `accept` = `self` type. Until then, `self` exists only for imports.

## 4. Placeholders and resolution

Placeholders (from the packs format): `{{ayah:S:A}}`, `{{arabic:S:A}}`, `{{word:S:A:W}}`,
`{{meaning:S:A:W}}`, `{{blank:S:A:W}}`, `{{hadith:collection:n}}`.

- `PlaceholderParser` (pure Dart, `saff_domain`) finds placeholders in any text field.
- `ContentRepository.resolveRound(round, translation)` collects all placeholders of a locked round, calls
  the gateway's batch `POST /resolve`, and stores results in Drift `resolved_content`.
- Rendering replaces each placeholder with a styled span: Arabic in the Quran font, right-to-left;
  `blank` renders the ayah with a gold underlined gap; translation in body style.
- Each member resolves with their own translation setting; cards are the same, only display text differs.
- Unresolved placeholder at play time: Arabic-only fallback; if nothing renders, the client flags the
  card `unresolvable` in its result and the server excludes it for everyone.

## 5. Learning track (personal)

- **Paths** from `index.json` → `paths` (e.g. Juz Amma 114 → 95). Each user picks their own path and goal.
- **Lessons** from each surah pack's `lessons.json`: ayah range, title, summary, new words, review words,
  card ids in order.
- **Lesson screen** reads lessons and resolves `{{arabic}}`, `{{ayah}}`, word data via the gateway's
  `/surah` and `/words` endpoints (cached in Drift), with recitation and per-word audio.
- **Unlocking:** surahs unlock in path order; within a surah, lessons in order. A user can study ahead
  of their daily goal; the goal counts minimum progress.
- **Eligibility:** a card is eligible for a user when every ayah in its `covers` is in a lesson they learned.
- **Scheduling (server):** `ts-fsrs` per user, desired retention 0.9, fuzzing off, learning steps disabled.
  Correct (or self-graded "I knew it") → Good; wrong → Again. State in `users/{uid}/learning/{itemId}`.
- **Where reviews are played:** both in the morning (Learning Duel, each participant gets their own cards)
  and in the Learn tab ("Review now", solo, graded by `submitReview`). Same schedule, one daily cap.
- Cross-surah references (cards mentioning earlier surahs) rely on path order; the app enforces path order.

## 6. Anki import

### 6.1 Supported inputs
| Input | Notes |
|---|---|
| `.apkg` latest (`collection.anki21b`, zstd) | Default export of current Anki |
| `.apkg` legacy 2 (`collection.anki21`) | "Support older Anki versions" export; most shared decks |
| `.apkg` legacy 1 (`collection.anki2`) | Very old exports |
| `.txt` / `.csv` / `.tsv` | Anki "Notes in Plain Text" export, or any 2-column file |
| `.colpkg` | Not supported (whole collections); error `IMPORT_UNSUPPORTED_FORMAT` |

### 6.2 Mapping
| Anki note type | Becomes |
|---|---|
| Basic, Basic (type in the answer) | 1 card: Front → question, Back → answer |
| Basic (and reversed / optional reversed) | 1 card (forward only) in v1 |
| Cloze | 1 card per cloze number: text with that cloze as `____`, answer = cloze text, hint dropped |
| Image occlusion, other media-only types | Skipped (`MEDIA_SKIPPED`) |
| Any other type | Field 1 → question, field 2 → answer, remaining fields appended to explanation (≤ 300 chars) |

- Tags → `tags`; deck name → pack title (editable before confirming).
- Card type rule: answer ≤ 4 words and ≤ 40 chars → `typed` (accept = answer + normalised variants);
  else `self`.
- Category for imported cards: `custom`; difficulty `medium` (Anki has no difficulty; FSRS data ignored).
- Talk prompt: none (optional field left empty; the review screen hides the talk section).

### 6.3 Flow in the app
Settings → Mornings → Import Anki deck → pick file → upload with progress → server parses →
preview (title, counts, warnings, 5 sample cards) → **Add to my saff** (members see a chat system card
"Hamza added the deck Medical Terms (812 cards)") → appears in Card mix.

### 6.4 Limits
`IMPORT_MAX_FILE` 50 MB, `IMPORT_MAX_CARDS` 2,000 per import, `IMPORTS_PER_SAFF` 10. Imported packs can be
deleted by the importer or the owner.

## 7. Library search (planting "Send a library card")

Drift FTS5 table over enabled packs' questions and topics; results filtered to cards the recipients
haven't seen (best effort, using the saff's seen list mirrored at lock time).
