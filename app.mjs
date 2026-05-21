import { incrementScore, loadScore, saveScore } from "./app-state.mjs";

const scoreValue = document.querySelector("[data-score]");
const clickButton = document.querySelector("[data-click-button]");

let score = loadScore(window.localStorage);

function render() {
  scoreValue.textContent = String(score);
}

clickButton.addEventListener("click", () => {
  score = incrementScore(score);
  score = saveScore(window.localStorage, score);
  render();
});

render();
