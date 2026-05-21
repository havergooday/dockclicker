import test from "node:test";
import assert from "node:assert/strict";

import {
  incrementScore,
  loadScore,
  normalizeScore,
  saveScore,
} from "./app-state.mjs";

test("normalizeScore returns 0 for invalid values", () => {
  assert.equal(normalizeScore(null), 0);
  assert.equal(normalizeScore(undefined), 0);
  assert.equal(normalizeScore("abc"), 0);
  assert.equal(normalizeScore(-3), 0);
});

test("loadScore restores a saved numeric score", () => {
  const storage = {
    getItem(key) {
      assert.equal(key, "dockclicker-score");
      return "12";
    },
  };

  assert.equal(loadScore(storage), 12);
});

test("incrementScore adds one to the current score", () => {
  assert.equal(incrementScore(0), 1);
  assert.equal(incrementScore(9), 10);
});

test("saveScore stores the normalized score as text", () => {
  let savedKey = "";
  let savedValue = "";

  const storage = {
    setItem(key, value) {
      savedKey = key;
      savedValue = value;
    },
  };

  saveScore(storage, 7);

  assert.equal(savedKey, "dockclicker-score");
  assert.equal(savedValue, "7");
});
