import { FieldValue, Timestamp, type Firestore } from "firebase-admin/firestore";
import { currentConstants } from "../../core/config";
import { log } from "../../core/logger";
import { pickCards, withShuffledOptions } from "../../domain/rounds/cards";
import { hash32, mulberry32, shuffled } from "../../domain/rounds/prng";
import type { PackCard } from "../../domain/rounds/cards";
import { matchesTyped } from "../../domain/rounds/normalise";
import { expireProposals } from "../alarms/proposals";
import { planAlarm } from "../alarms/planning";
import { officialCards } from "./packs";
import { applyStats } from "./stats";
import { pushToUser } from "./push";

/** Modes the server can currently assemble and grade. */
export const IMPLEMENTED_MODES = ["cardDuel", "climber", "rapidRoll"] as const;

function pickMode(occId: string, schedule: { type?: string; single?: string } | undefined): string {
  if (schedule?.type === "single" && (IMPLEMENTED_MODES as readonly string[]).includes(schedule.single ?? "")) {
    return schedule.single!;
  }
  const rnd = mulberry32(hash32(`${occId}:mode`));
  const r = rnd();
  return r < 30 / 60 ? "cardDuel" : r < 45 / 60 ? "climber" : "rapidRoll";
}

/** Locks the round for [occId] if it is still planned (idempotent). */
export async function lockRound(db: Firestore, saffId: string, occId: string): Promise<boolean> {
  const c = currentConstants();
  const occRef = db.doc(`saffs/${saffId}/occurrences/${occId}`);
  const saffRef = db.doc(`saffs/${saffId}`);
  const pool = await officialCards();
  const customCards = await importedCards(db, saffId);
  const locked = await db.runTransaction(async (tx) => {
    const [occ, saff, seen, plantSnap] = await Promise.all([
      tx.get(occRef),
      tx.get(saffRef),
      tx.get(saffRef.collection("seenCards").doc("main")),
      tx.get(occRef.collection("plants")),
    ]);
    if (!occ.exists || occ.get("status") !== "planned") return undefined;
    const required = occ.get("requiredIds") as string[];
    if (required.length === 0 || saff.get("endedAt")) {
      tx.update(occRef, { status: "cancelled" });
      return undefined;
    }
    const seenIds = new Set((seen.get("ids") as string[] | undefined) ?? []);
    const mix = saff.get("cardMix") as { generalKnowledge?: boolean } | undefined;
    const mode = pickMode(occId, saff.get("modeSchedule") as { type?: string; single?: string } | undefined);
    let cards = mode !== "cardDuel" ? [] : pickCards({
      pool,
      seenIds,
      occurrenceId: occId,
      count: c.cardsPerRound,
      generalKnowledge: mix?.generalKnowledge ?? true,
    }).map((card) => withShuffledOptions(card, occId));
    if (mode === "cardDuel" && cards.length === 0) {
      tx.update(occRef, { status: "cancelled" });
      return undefined;
    }
    cards = cards.slice(0, c.cardsPerRound);
    if (mode === "cardDuel" && (mix as { custom?: boolean } | undefined)?.custom && customCards.length > 0) {
      const rnd = mulberry32(hash32(`${occId}:custom`));
      const fresh = customCards.filter((x) => !seenIds.has(x.id));
      const picks = shuffled(fresh.length >= 4 ? fresh : customCards, rnd).slice(0, 4);
      cards = [...cards.slice(0, Math.max(0, cards.length - picks.length)), ...picks.map((x) => withShuffledOptions(x, occId))];
    }
    tx.set(saffRef.collection("rounds").doc(occId), {
      mode,
      seed: hash32(occId),
      cards,
      bonusCards: plantSnap.docs
        .sort((a, b) => (a.get("createdAt") as Timestamp).toMillis() - (b.get("createdAt") as Timestamp).toMillis())
        .map((d) => ({ ...(d.get("card") as object), authorId: d.get("authorId") })),
      packVersions: {},
      lockedAt: FieldValue.serverTimestamp(),
      status: "locked",
      ringAt: occ.get("ringAt"),
      deadlineAt: occ.get("deadlineAt"),
      requiredIds: required,
      alarmName: occ.get("alarmName"),
    });
    if (cards.length > 0) {
      tx.set(
        saffRef.collection("seenCards").doc("main"),
        { ids: FieldValue.arrayUnion(...cards.map((x) => x.id)) },
        { merge: true },
      );
    }
    tx.update(occRef, { status: "locked" });
    return required;
  });
  if (!locked) return false;
  log.info("round_locked", { saffId, occurrenceId: occId });
  for (const uid of locked) {
    await pushToUser(db, uid, { type: "roundLocked", saffId, occurrenceId: occId, v: "1" });
  }
  return true;
}

/** Marks required members with no sign of life as offline and alerts the rest. */
export async function offlineCheck(db: Firestore, saffId: string, occId: string): Promise<void> {
  const occRef = db.doc(`saffs/${saffId}/occurrences/${occId}`);
  const occ = await occRef.get();
  if (occ.get("status") !== "locked" || occ.get("offlineChecked")) return;
  const required = occ.get("requiredIds") as string[];
  const ringAt = (occ.get("ringAt") as Timestamp).toMillis();
  const presence = await db.collection(`saffs/${saffId}/rounds/${occId}/presence`).get();
  const seen = new Map(presence.docs.map((d) => [d.id, d]));
  const offline: string[] = [];
  const batch = db.batch();
  for (const uid of required) {
    const p = seen.get(uid);
    const at = (p?.get("updatedAt") as Timestamp | undefined)?.toMillis() ?? 0;
    if (!p || at < ringAt) {
      offline.push(uid);
      batch.set(
        db.doc(`saffs/${saffId}/rounds/${occId}/presence/${uid}`),
        { status: "offline", updatedAt: FieldValue.serverTimestamp() },
        { merge: true },
      );
    }
  }
  batch.update(occRef, { offlineChecked: true });
  await batch.commit();
  for (const uid of required.filter((u) => !offline.includes(u))) {
    for (const o of offline) {
      await pushToUser(db, uid, { type: "offlineAlert", saffId, occurrenceId: occId, uid: o, v: "1" });
    }
  }
}

/** Marks members who never played as missed and reveals (idempotent). */
export async function deadline(db: Firestore, saffId: string, occId: string): Promise<void> {
  const occ = await db.doc(`saffs/${saffId}/occurrences/${occId}`).get();
  if (occ.get("status") !== "locked") return;
  const required = occ.get("requiredIds") as string[];
  const results = await db.collection(`saffs/${saffId}/rounds/${occId}/results`).get();
  const done = new Set(results.docs.map((d) => d.id));
  const batch = db.batch();
  for (const uid of required.filter((u) => !done.has(u))) {
    batch.set(
      db.doc(`saffs/${saffId}/rounds/${occId}/presence/${uid}`),
      { status: "missed", updatedAt: FieldValue.serverTimestamp() },
      { merge: true },
    );
  }
  await batch.commit();
  await reveal(db, saffId, occId, { force: true });
}

interface CardResultAnswer {
  cardId: string;
  answer?: string;
  choiceIndex?: number;
  selfGrade?: boolean;
  msToAnswer: number;
}

/** Grades one member's result into `grades/{uid}`. */
export async function gradeResult(db: Firestore, saffId: string, occId: string, uid: string) {
  const c = currentConstants();
  const roundRef = db.doc(`saffs/${saffId}/rounds/${occId}`);
  const [round, result] = await Promise.all([
    roundRef.get(),
    roundRef.collection("results").doc(uid).get(),
  ]);
  if (!round.exists || !result.exists) return;
  const cards = round.get("cards") as {
    id: string;
    type: string;
    answer: string;
    options?: string[];
    accept?: string[];
  }[];
  const answers = (result.get("answers") as CardResultAnswer[]) ?? [];
  const perCard = cards.map((card) => {
    const a = answers.find((x) => x.cardId === card.id);
    let correct = false;
    if (a) {
      if (card.type === "choice") {
        correct = a.choiceIndex !== undefined && card.options?.[a.choiceIndex] === card.answer;
      } else if (card.type === "typed") {
        correct = !!a.answer && matchesTyped(a.answer, [card.answer, ...(card.accept ?? [])]);
      } else {
        correct = a.selfGrade === true;
      }
    }
    const left = a ? Math.max(0, 1 - a.msToAnswer / c.cardSecondsMs) : 0;
    const points = correct ? 10 + (card.type === "self" ? 0 : Math.round(5 * left)) : 0;
    return { cardId: card.id, correct, points, answered: !!a };
  });
  const offline = result.get("offlineFallback") === true;
  if (["climber", "rapidRoll"].includes(round.get("mode") as string)) {
    const score = Math.max(0, Math.floor((result.get("arcadeScore") as number | undefined) ?? 0));
    await roundRef.collection("grades").doc(uid).set({
      points: score,
      correct: 0,
      total: 0,
      perCard: [],
      woke: true,
      ranked: !offline,
      totalMs: 0,
      gradedAt: FieldValue.serverTimestamp(),
    });
    await roundRef.collection("presence").doc(uid).set(
      { status: "done", updatedAt: FieldValue.serverTimestamp() },
      { merge: true },
    );
    return;
  }
  await roundRef.collection("grades").doc(uid).set({
    points: perCard.reduce((s, p) => s + p.points, 0),
    correct: perCard.filter((p) => p.correct).length,
    total: cards.length,
    perCard,
    woke: true,
    ranked: !offline,
    totalMs: answers
      .filter((x) => cards.some((cd) => cd.id === x.cardId))
      .reduce((s, x) => s + (x.msToAnswer ?? 0), 0),
    gradedAt: FieldValue.serverTimestamp(),
  });
  await roundRef.collection("presence").doc(uid).set(
    { status: "done", updatedAt: FieldValue.serverTimestamp() },
    { merge: true },
  );
}

/**
 * Reveals the round once: when every required member has a grade, or at the
 * deadline when [force] is set. Transactional and idempotent.
 */
export async function reveal(
  db: Firestore,
  saffId: string,
  occId: string,
  options: { force?: boolean } = {},
): Promise<boolean> {
  const roundRef = db.doc(`saffs/${saffId}/rounds/${occId}`);
  const occRef = db.doc(`saffs/${saffId}/occurrences/${occId}`);
  const saffRef = db.doc(`saffs/${saffId}`);
  const revealed = await db.runTransaction(async (tx) => {
    const [round, occ, saff, grades, results, members] = await Promise.all([
      tx.get(roundRef),
      tx.get(occRef),
      tx.get(saffRef),
      tx.get(roundRef.collection("grades")),
      tx.get(roundRef.collection("results")),
      tx.get(saffRef.collection("members")),
    ]);
    if (!round.exists || round.get("status") !== "locked") return undefined;
    const required = occ.get("requiredIds") as string[];
    const graded = new Set(grades.docs.map((g) => g.id));
    const allIn = required.every((u) => graded.has(u));
    if (!allIn && !options.force) return undefined;

    const resultById = new Map(results.docs.map((r) => [r.id, r]));
    const memberById = new Map(members.docs.map((m) => [m.id, m]));
    const cards = round.get("cards") as { id: string }[];
    const bonus = (round.get("bonusCards") as { id: string; type: string; answer: string; options?: string[]; accept?: string[] }[]) ?? [];
    const rows = required.map((uid) => {
      const g = grades.docs.find((x) => x.id === uid);
      const r = resultById.get(uid);
      return {
        uid,
        name: (memberById.get(uid)?.get("displayName") as string) ?? "",
        avatarColor: (memberById.get(uid)?.get("avatarColor") as string) ?? "0",
        played: !!g,
        points: (g?.get("points") as number | undefined) ?? 0,
        correct: (g?.get("correct") as number | undefined) ?? 0,
        total: cards.length,
        totalMs: (g?.get("totalMs") as number | undefined) ?? 0,
        ranked: (g?.get("ranked") as boolean | undefined) ?? false,
        wakeMs: (r?.get("wakeMs") as number | undefined) ?? null,
        snoozed: (r?.get("snoozed") as boolean | undefined) ?? false,
        woke: !!g,
        offlineFallback: (r?.get("offlineFallback") as boolean | undefined) ?? false,
        rank: 0,
      };
    });
    const ranked = rows.filter((r) => r.played && r.ranked && required.length > 1);
    ranked.sort((a, b) => b.points - a.points || a.totalMs - b.totalMs);
    let rank = 0;
    ranked.forEach((r, i) => {
      if (i === 0 || r.points !== ranked[i - 1]!.points) rank = i + 1;
      r.rank = rank;
    });
    const wakers = rows.filter((r) => r.woke && r.wakeMs !== null);
    wakers.sort((a, b) => (a.wakeMs ?? 0) - (b.wakeMs ?? 0));
    const firstWaker = wakers[0]?.uid ?? null;
    const everyoneWoke = required.length > 0 && rows.every((r) => r.woke);
    const streak = (saff.get("streak") as { current?: number; longest?: number }) ?? {};
    const current = everyoneWoke ? (streak.current ?? 0) + 1 : 0;

    const perCard = [...cards, ...bonus].map((card) => ({
      cardId: card.id,
      answers: required.map((uid) => {
        const g = grades.docs.find((x) => x.id === uid);
        const bonusDef = bonus.find((b) => b.id === card.id);
        const given = (
          resultById.get(uid)?.get("answers") as
            | { cardId: string; answer?: string; choiceIndex?: number }[]
            | undefined
        )?.find((x) => x.cardId === card.id);
        const pc = bonusDef
          ? {
              cardId: card.id,
              correct:
                bonusDef.type === "choice"
                  ? given?.choiceIndex !== undefined && bonusDef.options?.[given.choiceIndex] === bonusDef.answer
                  : bonusDef.type === "typed"
                    ? !!given?.answer && matchesTyped(given.answer, [bonusDef.answer, ...(bonusDef.accept ?? [])])
                    : false,
            }
          : (g?.get("perCard") as { cardId: string; correct: boolean }[] | undefined)?.find(
              (p) => p.cardId === card.id,
            );
        const a = (
          resultById.get(uid)?.get("answers") as
            | { cardId: string; answer?: string; choiceIndex?: number }[]
            | undefined
        )?.find((x) => x.cardId === card.id);
        return {
          uid,
          correct: pc?.correct ?? false,
          answered: !!a,
          answer: a?.answer ?? null,
          choiceIndex: a?.choiceIndex ?? null,
        };
      }),
    }));

    tx.set(roundRef.collection("reveal").doc("summary"), {
      rows,
      firstWaker,
      streak: current,
      everyoneWoke,
      perCard,
      bonusCards: bonus.map((b) => ({ ...b, fromName: memberById.get((b as { authorId?: string }).authorId ?? "")?.get("displayName") ?? "" })),
      mode: round.get("mode"),
      solo: required.length === 1,
      revealedAt: FieldValue.serverTimestamp(),
    });
    tx.update(roundRef, { status: "revealed", revealedAt: FieldValue.serverTimestamp() });
    tx.update(occRef, { status: "revealed" });
    tx.update(saffRef, {
      streak: { current, longest: Math.max(streak.longest ?? 0, current), lastOccurrenceId: occId },
    });
    tx.set(saffRef.collection("messages").doc(`sys_round_result_${occId}`), {
      type: "round_result",
      authorId: "system",
      systemPayload: {
        occurrenceId: occId,
        mode: round.get("mode"),
        winnerUid: ranked[0]?.uid ?? null,
        players: rows.filter((r) => r.played).length,
        alarmName: occ.get("alarmName"),
        date: occ.get("date"),
      },
      createdAt: FieldValue.serverTimestamp(),
      seenBy: {},
    });
    return required;
  });
  if (!revealed) return false;
  log.info("round_revealed", { saffId, occurrenceId: occId });
  try {
    await applyStats(db, saffId, occId);
  } catch (e) {
    // Stats are rebuildable; never fail the reveal over them.
    log.error("stats_failed", { saffId, occurrenceId: occId, error: String(e) });
  }
  for (const uid of revealed) {
    await pushToUser(db, uid, { type: "reveal", saffId, occurrenceId: occId, v: "1" }, {
      notification: { title: "Results are in", body: "See how the morning went" },
      highPriority: false,
    });
  }
  return true;
}

/** One pass of everything time-driven. Called by the scheduler and the dev ticker. */
export async function runSweep(db: Firestore, nowMs = Date.now()): Promise<Record<string, number>> {
  const c = currentConstants();
  const stats = { planned: 0, locked: 0, offline: 0, deadlines: 0, expired: 0 };

  // Keep a week of occurrences planned (hourly).
  const state = db.doc("config/sweeper");
  const last = ((await state.get()).get("lastPlanAt") as number | undefined) ?? 0;
  if (nowMs - last > 3_600_000) {
    const alarms = await db.collectionGroup("alarms").where("status", "==", "active").get();
    for (const a of alarms.docs) {
      await planAlarm(db, a.ref.parent.parent!.id, a.id, nowMs);
      stats.planned++;
    }
    await state.set({ lastPlanAt: nowMs }, { merge: true });
  }

  const planned = await db.collectionGroup("occurrences").where("status", "==", "planned").get();
  for (const o of planned.docs) {
    const lockAt = (o.get("lockAt") as Timestamp).toMillis();
    const deadlineAt = (o.get("deadlineAt") as Timestamp).toMillis();
    if (lockAt <= nowMs && deadlineAt > nowMs) {
      if (await lockRound(db, o.ref.parent.parent!.id, o.id)) stats.locked++;
    }
  }
  const locked = await db.collectionGroup("occurrences").where("status", "==", "locked").get();
  for (const o of locked.docs) {
    const saffId = o.ref.parent.parent!.id;
    const ringAt = (o.get("ringAt") as Timestamp).toMillis();
    const deadlineAt = (o.get("deadlineAt") as Timestamp).toMillis();
    if (!o.get("offlineChecked") && ringAt + c.offlineCheckDelayMs <= nowMs) {
      await offlineCheck(db, saffId, o.id);
      stats.offline++;
    }
    if (deadlineAt <= nowMs) {
      await deadline(db, saffId, o.id);
      stats.deadlines++;
    }
  }
  stats.expired = await expireProposals(db, nowMs);
  return stats;
}

/** Cards of the saff's imported packs. */
async function importedCards(db: Firestore, saffId: string): Promise<PackCard[]> {
  const chunks = await db.collectionGroup("chunks").get();
  const out: PackCard[] = [];
  for (const d of chunks.docs) {
    if (!d.ref.path.startsWith(`saffs/${saffId}/packs/`)) continue;
    out.push(...((d.get("cards") as PackCard[]) ?? []));
  }
  return out;
}
