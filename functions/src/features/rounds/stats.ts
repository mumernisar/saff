import { FieldValue, type Firestore } from "firebase-admin/firestore";
import { dayStatus, headToHead, newBadges, type MemberOutcome } from "../../domain/stats";

/**
 * Applies one revealed occurrence to the stats docs (idempotent through a
 * marker doc): saff summary, month calendar, head-to-head, first waker,
 * nudge counts, personal counters and badges.
 */
export async function applyStats(db: Firestore, saffId: string, occId: string): Promise<void> {
  const saffRef = db.doc(`saffs/${saffId}`);
  const roundRef = saffRef.collection("rounds").doc(occId);
  const marker = saffRef.collection("stats").doc(`applied_${occId}`);
  const nudgeSnap = await roundRef.collection("nudges").get();

  await db.runTransaction(async (tx) => {
    const [mark, occ, summary, saff, userStreaks] = await Promise.all([
      tx.get(marker),
      tx.get(saffRef.collection("occurrences").doc(occId)),
      tx.get(roundRef.collection("reveal").doc("summary")),
      tx.get(saffRef),
      Promise.resolve(null),
    ]);
    void userStreaks;
    if (mark.exists || !summary.exists || !occ.exists) return;

    const date = occ.get("date") as string;
    const month = date.slice(0, 6);
    const skipped = new Set((occ.get("skippedIds") as string[]) ?? []);
    const participants = (occ.get("participantIds") as string[]) ?? [];
    const rows = (summary.get("rows") as {
      uid: string;
      played: boolean;
      points: number;
      ranked: boolean;
      wakeMs: number | null;
      snoozed: boolean;
    }[]) ?? [];
    const outcomes: MemberOutcome[] = participants.map((uid) => {
      const r = rows.find((x) => x.uid === uid);
      return {
        uid,
        woke: !!r?.played,
        skipped: skipped.has(uid),
        ranked: !!r?.ranked,
        points: r?.points ?? 0,
        wakeMs: r?.wakeMs ?? null,
        snoozed: !!r?.snoozed,
      };
    });
    const status = dayStatus(outcomes);
    const solo = outcomes.filter((o) => !o.skipped).length === 1;
    const streak = (saff.get("streak") as { current?: number })?.current ?? 0;

    // Reads for personal docs must precede writes.
    const userRefs = outcomes.map((o) => db.doc(`users/${o.uid}/stats/summary`));
    const badgeSnaps = await Promise.all(
      outcomes.map((o) => tx.get(db.collection(`users/${o.uid}/badges`))),
    );
    const userSnaps = await Promise.all(userRefs.map((r) => tx.get(r)));

    const dayEntry = {
      status,
      alarmName: occ.get("alarmName"),
      winner: (summary.get("rows") as { uid: string; rank: number }[]).find((r) => r.rank === 1 && !solo)?.uid ?? null,
      mode: summary.get("mode"),
      streak,
      members: Object.fromEntries(
        outcomes.map((o) => [
          o.uid,
          { woke: o.woke, skipped: o.skipped, points: o.points, wakeMs: o.wakeMs },
        ]),
      ),
    };
    tx.set(
      saffRef.collection("stats").doc(`days_${month}`),
      { days: { [date]: dayEntry } },
      { merge: true },
    );

    const counted = status !== "grey";
    const nudgesSent: Record<string, FieldValue> = {};
    const nudgesRecv: Record<string, FieldValue> = {};
    for (const n of nudgeSnap.docs) {
      nudgesSent[`nudgesSent.${n.get("fromId")}`] = FieldValue.increment(1);
      nudgesRecv[`nudgesReceived.${n.get("toId")}`] = FieldValue.increment(1);
    }
    const h2h: Record<string, FieldValue> = {};
    for (const p of headToHead(outcomes)) {
      const key = `h2h.${p.a}_${p.b}.${p.result === "a" ? "aWins" : p.result === "b" ? "bWins" : "draws"}`;
      h2h[key] = FieldValue.increment(1);
    }
    const first = summary.get("firstWaker") as string | null;
    tx.set(
      saffRef.collection("stats").doc("summary"),
      {
        ...(counted ? { rounds: FieldValue.increment(1) } : {}),
        ...(status === "green" ? { everyoneUp: FieldValue.increment(1) } : {}),
        ...(first ? { [`firstWaker.${first}`]: FieldValue.increment(1) } : {}),
        longestStreak: Math.max((saff.get("streak") as { longest?: number })?.longest ?? 0, streak),
        ...nudgesSent,
        ...nudgesRecv,
        ...h2h,
      },
      { merge: true },
    );

    outcomes.forEach((o, i) => {
      if (o.skipped) return;
      const prev = userSnaps[i]!;
      const personal = (prev.get("streak") as number | undefined) ?? 0;
      const current = o.woke ? personal + 1 : 0;
      const roundsWoke = ((prev.get("roundsWoke") as number | undefined) ?? 0) + (o.woke ? 1 : 0);
      const lightning = ((prev.get("lightning") as number | undefined) ?? 0) +
        (o.woke && o.wakeMs !== null && o.wakeMs <= 15_000 ? 1 : 0);
      const noSnooze = ((prev.get("noSnooze") as number | undefined) ?? 0) + (o.woke && !o.snoozed ? 1 : 0);
      const wakeSum = ((prev.get("wakeMsSum") as number | undefined) ?? 0) + (o.woke ? (o.wakeMs ?? 0) : 0);
      tx.set(
        userRefs[i]!,
        {
          streak: current,
          longestStreak: Math.max((prev.get("longestStreak") as number | undefined) ?? 0, current),
          rounds: FieldValue.increment(1),
          roundsWoke,
          lightning,
          noSnooze,
          wakeMsSum: wakeSum,
          wakeCount: FieldValue.increment(o.woke ? 1 : 0),
        },
        { merge: true },
      );
      const have = new Set(badgeSnaps[i]!.docs.map((d) => d.id));
      for (const id of newBadges({ saffStreak: streak, roundsWoke, lightning, noSnooze, have })) {
        tx.set(db.doc(`users/${o.uid}/badges/${id}`), { earnedAt: FieldValue.serverTimestamp(), saffId });
      }
    });
    tx.set(marker, { at: FieldValue.serverTimestamp() });
  });
}
