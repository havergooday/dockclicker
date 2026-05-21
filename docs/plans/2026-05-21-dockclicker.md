# Dockclicker First Screen Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 브라우저에서 바로 열 수 있는 최소 클리커 화면과 점수 저장/복원 기능을 만든다.

**Architecture:** 정적 페이지 위에 상태 모듈과 DOM 연결 모듈을 분리한다. 상태 모듈은 저장/복원 로직을 포함하고, DOM 모듈은 버튼 클릭과 화면 갱신만 담당한다.

**Tech Stack:** HTML, CSS, vanilla JavaScript ES modules, Node built-in test runner

---

### Task 1: Project Skeleton

**Files:**
- Create: `index.html`
- Create: `styles.css`
- Create: `app.mjs`
- Create: `app-state.mjs`
- Create: `package.json`

**Step 1: Write the failing test**

Create a test file after the state module path is decided.

**Step 2: Run test to verify it fails**

Run: `node --test app-state.test.mjs`
Expected: FAIL because the module and functions do not exist yet.

**Step 3: Write minimal implementation**

Create the state module with score normalization, load, save, and increment helpers. Create the HTML, CSS, and browser module that renders the score and binds the button.

**Step 4: Run test to verify it passes**

Run: `node --test app-state.test.mjs`
Expected: PASS

**Step 5: Commit**

```bash
git add .
git commit -m "feat: add first dockclicker screen"
```

### Task 2: State Logic Test Coverage

**Files:**
- Create: `app-state.test.mjs`
- Test: `app-state.test.mjs`

**Step 1: Write the failing test**

Add tests for:
- invalid stored values become `0`
- valid stored values are restored
- increment returns current score + 1

**Step 2: Run test to verify it fails**

Run: `node --test app-state.test.mjs`
Expected: FAIL until helpers exist and behave correctly.

**Step 3: Write minimal implementation**

Implement only the helpers required by the tests.

**Step 4: Run test to verify it passes**

Run: `node --test app-state.test.mjs`
Expected: PASS

**Step 5: Commit**

```bash
git add app-state.mjs app-state.test.mjs
git commit -m "test: cover clicker state storage"
```

### Task 3: Manual Browser Verification

**Files:**
- Verify: `index.html`

**Step 1: Open the page in a browser**

Check that the score is visible and the button is clickable.

**Step 2: Click multiple times**

Expected: score increases immediately.

**Step 3: Refresh**

Expected: score remains the same.
