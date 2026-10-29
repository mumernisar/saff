// Acts as another test user against the local emulators, so one phone can
// run a two-person morning. Dev tool (docs/DEMO.md).
// Usage: node tools/demo/peer.mjs <name> <command> [args]
//   profile                      create the profile (+92300 number)
//   join CODE                    join a saff by code
//   saffs                        list the user's saffs
//   propose SAFFID MINUTES       propose an alarm MINUTES from now (Asia/Karachi)
//   vote SAFFID accept|decline   vote on the newest pending proposal
//   say SAFFID TEXT              send a chat message
//   play SAFFID OCCID [delayMs]  answer the locked round correctly and submit
//   nudge SAFFID OCCID TARGET    ring TARGET (a name) again
import { createRequire } from "node:module";
const require = createRequire(new URL("../../firebase/rules-tests/", import.meta.url));
const { initializeApp } = require("firebase/app");
const { getAuth, connectAuthEmulator, createUserWithEmailAndPassword, signInWithEmailAndPassword } = require("firebase/auth");
const { getFunctions, connectFunctionsEmulator, httpsCallable } = require("firebase/functions");
const { getFirestore, connectFirestoreEmulator, doc, getDoc, getDocs, collection, setDoc, addDoc, query, where, serverTimestamp } = require("firebase/firestore");

const PROJECT = "saff-dev-d9605";
const HOST = process.env.EMULATOR_HOST ?? "127.0.0.1";
const [name, cmd, ...args] = process.argv.slice(2);

const app = initializeApp({ projectId: PROJECT, apiKey: "demo", appId: "demo" }, name);
const auth = getAuth(app);
connectAuthEmulator(auth, `http://${HOST}:9099`, { disableWarnings: true });
const fns = getFunctions(app, "us-central1");
connectFunctionsEmulator(fns, HOST, 5001);
const fs = getFirestore(app);
connectFirestoreEmulator(fs, HOST, 8080);
const email = `${name.toLowerCase()}@test.saff`;
try { await signInWithEmailAndPassword(auth, email, "password1"); }
catch { await createUserWithEmailAndPassword(auth, email, "password1"); }
const uid = auth.currentUser.uid;
const call = async (fn, data) => (await httpsCallable(fns, fn)(data)).data;

switch (cmd) {
  case "profile":
    console.log(await call("setProfile", { displayName: name, whatsapp: "+923007654321" }));
    break;
  case "create":
    console.log(await call("createSaff", {}));
    break;
  case "delete":
    console.log(await call("deleteAccount", {}));
    break;
  case "join":
    console.log(await call("joinSaff", { code: args[0] }));
    break;
  case "saffs": {
    const u = await getDoc(doc(fs, `users/${uid}`));
    console.log(u.get("saffIds"));
    break;
  }
  case "propose": {
    const at = new Date(Date.now() + Number(args[1]) * 60_000 + 5 * 3600_000);
    const time = `${String(at.getUTCHours()).padStart(2, "0")}:${String(at.getUTCMinutes()).padStart(2, "0")}`;
    console.log(await call("createProposal", {
      saffId: args[0], type: "alarmCreate",
      payload: { name: "Fajr", time, days: [1, 2, 3, 4, 5, 6, 7], timezone: "Asia/Karachi" },
    }), time);
    break;
  }
  case "vote": {
    const ps = await getDocs(query(collection(fs, `saffs/${args[0]}/proposals`), where("status", "==", "pending")));
    for (const p of ps.docs) console.log(await call("voteProposal", { saffId: args[0], proposalId: p.id, vote: args[1] }));
    break;
  }
  case "say":
    await addDoc(collection(fs, `saffs/${args[0]}/messages`), {
      type: "text", authorId: uid, text: args.slice(1).join(" "), createdAt: serverTimestamp(), seenBy: {},
    });
    break;
  case "play": {
    const round = await getDoc(doc(fs, `saffs/${args[0]}/rounds/${args[1]}`));
    const cards = round.get("cards");
    const arcade = ["climber", "rapidRoll"].includes(round.get("mode"));
    await setDoc(doc(fs, `saffs/${args[0]}/rounds/${args[1]}/presence/${uid}`), { status: "playing", updatedAt: serverTimestamp() });
    const answers = cards.map((c, i) => ({
      cardId: c.id,
      ...(c.type === "choice" ? { choiceIndex: c.options.indexOf(c.answer) } : { answer: c.answer }),
      msToAnswer: Number(args[2] ?? 4000) + i * 300,
    }));
    await setDoc(doc(fs, `saffs/${args[0]}/rounds/${args[1]}/results/${uid}`), {
      answers: arcade ? [] : answers, ...(arcade ? { arcadeScore: 640 } : {}),
      wakeMs: 20_000, snoozed: false, offlineFallback: false, finishedAt: serverTimestamp(),
    });
    console.log("submitted", round.get("mode"));
    break;
  }
  case "presence": {
    await setDoc(doc(fs, `saffs/${args[0]}/rounds/${args[1]}/presence/${uid}`), { status: args[2] ?? "asleep", updatedAt: serverTimestamp() });
    break;
  }
  case "nudge": {
    const members = await getDocs(collection(fs, `saffs/${args[0]}/members`));
    const t = members.docs.find((d) => d.get("displayName") === args[2]);
    console.log(await call("nudge", { saffId: args[0], occurrenceId: args[1], targetUid: t.id }));
    break;
  }
  default:
    console.log("unknown command");
}
process.exit(0);
