// End-to-end smoke test against the local emulators (dev tool, not a unit test).
// Usage: node tools/demo/smoke.mjs   (emulators must be running)
import { createRequire } from "node:module";
const require = createRequire(new URL("../../firebase/rules-tests/", import.meta.url));
const { initializeApp } = require("firebase/app");
const { getAuth, connectAuthEmulator, createUserWithEmailAndPassword, signInWithEmailAndPassword } = require("firebase/auth");
const { getFunctions, connectFunctionsEmulator, httpsCallable } = require("firebase/functions");
const { getFirestore, connectFirestoreEmulator, doc, getDoc, getDocs, collection, setDoc, serverTimestamp } = require("firebase/firestore");

const PROJECT = "saff-dev-d9605";
const HOST = process.env.EMULATOR_HOST ?? "127.0.0.1";

async function client(name) {
  const app = initializeApp({ projectId: PROJECT, apiKey: "demo", appId: "demo" }, name);
  const auth = getAuth(app);
  connectAuthEmulator(auth, `http://${HOST}:9099`, { disableWarnings: true });
  const fns = getFunctions(app, "us-central1");
  connectFunctionsEmulator(fns, HOST, 5001);
  const fs = getFirestore(app);
  connectFirestoreEmulator(fs, HOST, 8080);
  const email = `${name}@test.saff`;
  try { await createUserWithEmailAndPassword(auth, email, "password1"); }
  catch { await signInWithEmailAndPassword(auth, email, "password1"); }
  const call = async (fn, data) => (await httpsCallable(fns, fn)(data)).data;
  return { auth, fs, call, uid: auth.currentUser.uid };
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const tick = async () => (await fetch(`http://${HOST}:5001/${PROJECT}/us-central1/tick`)).json();

const stamp = Date.now().toString(36);
const hamza = await client(`hamza${stamp}`);
const ali = await client(`ali${stamp}`);
await hamza.call("setProfile", { displayName: "Hamza", whatsapp: "+923001234567" });
await ali.call("setProfile", { displayName: "Ali", whatsapp: "+923007654321" });
const { saffId, inviteCode } = await hamza.call("createSaff", {});
console.log("saff", saffId, inviteCode);
console.log("preview", JSON.stringify(await ali.call("previewInvite", { code: inviteCode })));
await ali.call("joinSaff", { code: inviteCode });

const at = new Date(Date.now() + 2 * 60_000);
const pk = new Date(at.getTime() + 5 * 3600_000); // Asia/Karachi wall clock
const time = `${String(pk.getUTCHours()).padStart(2, "0")}:${String(pk.getUTCMinutes()).padStart(2, "0")}`;
const { proposalId } = await hamza.call("createProposal", {
  saffId, type: "alarmCreate",
  payload: { name: "Fajr", time, days: [1, 2, 3, 4, 5, 6, 7], timezone: "Asia/Karachi" },
});
await ali.call("voteProposal", { saffId, proposalId, vote: "accept" });
const alarms = await getDocs(collection(hamza.fs, `saffs/${saffId}/alarms`));
console.log("alarms", alarms.docs.map((d) => [d.id, d.get("status"), d.get("time")]));
const occs = await getDocs(collection(hamza.fs, `saffs/${saffId}/occurrences`));
console.log("occurrences", occs.size);
const next = occs.docs.map((d) => d).sort((a, b) => a.get("ringAt").seconds - b.get("ringAt").seconds)[0];
console.log("next", next.id, new Date(next.get("ringAt").seconds * 1000).toISOString());
let round;
for (let i = 0; i < 30; i++) {
  const t = await tick();
  round = await getDoc(doc(hamza.fs, `saffs/${saffId}/rounds/${next.id}`));
  if (round.exists()) { console.log("tick", t); break; }
  await sleep(5000);
}
console.log("round", round.exists(), round.get("mode"), round.get("cards")?.length);
if (round.exists()) {
  const cards = round.get("cards");
  for (const u of [hamza, ali]) {
    const answers = cards.map((c, i) => ({
      cardId: c.id,
      ...(c.type === "choice" ? { choiceIndex: c.options.indexOf(c.answer) } : { answer: c.answer }),
      msToAnswer: 3000 + i * 500,
    }));
    await setDoc(doc(u.fs, `saffs/${saffId}/rounds/${next.id}/results/${u.uid}`), {
      answers, wakeMs: 10_000, snoozed: false, offlineFallback: false, finishedAt: serverTimestamp(),
    }).catch((e) => console.log("result write blocked:", e.code));
  }
  await sleep(4000);
  const summary = await getDoc(doc(hamza.fs, `saffs/${saffId}/rounds/${next.id}/reveal/summary`));
  console.log("reveal", summary.exists(), JSON.stringify(summary.get("rows")?.map((r) => [r.name, r.points, r.rank])));
}
process.exit(0);
