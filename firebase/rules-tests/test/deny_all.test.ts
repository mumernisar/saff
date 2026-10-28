import {
  assertFails,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { doc, getDoc, setDoc } from "firebase/firestore";
import { getBytes, ref, uploadString } from "firebase/storage";
import { readFileSync } from "node:fs";
import { afterAll, beforeAll, describe, it } from "vitest";

let env: RulesTestEnvironment;

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-saff-rules",
    firestore: {
      host: "127.0.0.1",
      port: 8080,
      rules: readFileSync("../firestore.rules", "utf8"),
    },
    storage: {
      host: "127.0.0.1",
      port: 9199,
      rules: readFileSync("../storage.rules", "utf8"),
    },
  });
});

afterAll(async () => {
  await env.cleanup();
});

describe("Stage 0 rules deny everything", () => {
  it("firestore: anonymous read and write fail", async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, "users/u1")));
    await assertFails(setDoc(doc(db, "users/u1"), { name: "x" }));
  });

  it("firestore: a signed-in user cannot read or write either", async () => {
    const db = env.authenticatedContext("u1").firestore();
    await assertFails(getDoc(doc(db, "users/u1")));
    await assertFails(setDoc(doc(db, "users/u1"), { name: "x" }));
    await assertFails(setDoc(doc(db, "config/backend"), { status: "ok" }));
  });

  it("storage: anonymous and signed-in read and write fail", async () => {
    const anon = env.unauthenticatedContext().storage();
    const user = env.authenticatedContext("u1").storage();
    await assertFails(uploadString(ref(anon, "selfies/a.jpg"), "x"));
    await assertFails(uploadString(ref(user, "selfies/a.jpg"), "x"));
    await assertFails(getBytes(ref(user, "selfies/a.jpg")));
  });
});
