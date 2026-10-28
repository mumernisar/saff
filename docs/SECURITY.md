# Security and privacy

## 1. Principles
- Least privilege: clients can read only their saff's data and write only their own documents.
- Server-only fields are never writable by clients (`[S]` in `DATA_MODEL.md`).
- All multi-document or rule-heavy actions go through callables, not direct writes.
- Personal data is minimal, visible only inside the saff, and never logged.

## 2. Firestore rules (outline)
```
function signedIn() { return request.auth != null; }
function member(saffId) {
  return signedIn() && request.auth.uid in get(/databases/$(db)/documents/saffs/$(saffId)).data.memberIds;
}
match /users/{uid} { allow read: if signedIn() && (request.auth.uid == uid || sharesSaff(uid));
                     allow update: if request.auth.uid == uid && onlyChanges(['displayName','avatarColor','settings','appVersion','platform','oem','androidSdk','lastActiveAt']); }
match /users/{uid}/private/{doc} { allow read, write: if request.auth.uid == uid; }
match /saffs/{saffId} { allow read: if member(saffId);
                        allow update: if member(saffId) && onlyChanges(['whatsappGroupLink']) && validWhatsAppLink(); }
match /saffs/{saffId}/messages/{id} {
  allow read: if member(saffId);
  allow create: if member(saffId) && request.resource.data.authorId == request.auth.uid
                && request.resource.data.type == 'text' && validText();
  allow update: if member(saffId) && (ownSeenByOnly() || ownDeleteWithinHour()); }
match /saffs/{saffId}/rounds/{rid}/results/{uid} {
  allow create: if member(saffId) && request.auth.uid == uid && roundLocked(saffId, rid) && beforeDeadline(saffId, rid);
  allow read: if request.auth.uid == uid || (member(saffId) && roundRevealed(saffId, rid)); }
match /config/backend { allow read: if signedIn(); allow write: if false; }   // billing-cap status, ERRORS.md §7a
... every other server-written collection: allow read: if member(saffId); allow write: if false;
```
- Rules are tested for every collection with allowed and denied cases (`firebase/rules-tests/`).
- Storage rules: `imports/{uid}/{file}`: write only by `uid`, size ≤ 50 MB, allowed content types; no reads.
  `saffs/{saffId}/rounds/{rid}/{uid}.jpg`: write once by `uid` if member, `image/jpeg`, ≤ 1 MB, before the
  round deadline; read by saff members only after the round is revealed (rules read the round doc).

## 3. App Check
Play Integrity provider in prod (debug provider in dev). Enforced on Firestore, Storage, Functions
(callables and the content gateway).

## 4. Secrets
- Quran Foundation client id/secret: Secret Manager (`defineSecret`), never in the app.
- `env/*.json` (client config, not secret but environment-specific) gitignored; Firebase options files
  per flavor are committed (they're public identifiers).
- Signing keys: CI secrets only.
- Play Developer API service-account key: Secret Manager; used only by billing functions.

## 4a. Purchases
- Entitlements are written only by the server after verifying with Google Play; clients can't write
  `users/{uid}/entitlement`, `purchases` or `purchaseTokens` (rules: `allow write: if false`).
- Raw purchase tokens live only in `purchaseTokens/{hash}` (no client access); everywhere else uses the hash.
- Play notifications are treated as hints: the subscription is always re-fetched from the Play API.
- Refunds/revocations remove Plus immediately; members are still never removed from saffs.

## 5. Abuse limits
- Callables have per-uid rate limits (e.g. `nudge` already rate-limited by rules of the game;
  `createProposal` ≤ 20/day; `joinSaff` ≤ 10 attempts/hour to stop code guessing).
- Message length ≤ 2,000 chars; planted card limits; import limits.
- Invite codes: 32^6 ≈ 1 billion combinations, plus attempt limits.

## 6. Account deletion (`deleteAccount`)
1. Leave every saff (ownership transfer / saff end as usual).
2. Delete `users/{uid}`, subcollections, devices, private contact, member docs.
3. Messages are **not rewritten** (cheapest for the system): they keep the deleted uid, and the app shows
   any author without a member document as "Deleted user". Results and grades keep only numbers.
4. Delete imports, uploaded files, selfies and personal learning data.
5. Delete the Auth user last. Idempotent; can be retried.
Also provide the web deletion URL the Play Store requires.

## 7. Personal data inventory
| Data | Where | Visible to |
|---|---|---|
| Email (auth) | Firebase Auth | Nobody in-app |
| Display name, avatar colour | `users`, member docs | Saff members |
| WhatsApp number | `users/{uid}/private`, member doc | User, saff members |
| Messages | saff messages | Saff members |
| Wake times, results | rounds | Saff members after reveal |
| Selfies | Storage, per round | Saff members after reveal, for 24 h; copies saved by a member stay in that member's gallery |
| Device info | `users`, `devices` | Server |
| Subscription status | `entitlement`, `purchases` | The user (status only), server |

The privacy policy and Play Data Safety form are written from this table.
