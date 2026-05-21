export const SCORE_KEY = "dockclicker-score";

export function normalizeScore(value) {
  const number = Number(value);

  if (!Number.isFinite(number) || number < 0) {
    return 0;
  }

  return Math.floor(number);
}

export function loadScore(storage) {
  return normalizeScore(storage?.getItem?.(SCORE_KEY));
}

export function saveScore(storage, score) {
  const normalized = normalizeScore(score);
  storage?.setItem?.(SCORE_KEY, String(normalized));
  return normalized;
}

export function incrementScore(score) {
  return normalizeScore(score) + 1;
}
