# Godot Bootstrap Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Godot 기반 출시형 프로젝트 구조와 최소 메인 씬 뼈대를 만든다.

**Architecture:** `project.godot`와 메인 씬을 기준으로 `autoload`, `core`, `ui`, `assets`, `data`, `docs`, `tests` 구조를 먼저 고정한다. 초기 범위는 창을 여는 최소 루트 구조와 문서화된 확장 포인트만 포함한다.

**Tech Stack:** Godot 4, GDScript, Python unittest

---

### Task 1: Structure Verification

**Files:**
- Create: `tests/test_project_structure.py`
- Test: `tests/test_project_structure.py`

**Step 1: Write the failing test**

Assert that the required bootstrap files and folders exist.

**Step 2: Run test to verify it fails**

Run: `python -m unittest tests.test_project_structure`
Expected: FAIL because the Godot scaffold does not exist yet.

**Step 3: Write minimal implementation**

Add the Godot project file, icon, docs, main scene, and starter scripts.

**Step 4: Run test to verify it passes**

Run: `python -m unittest tests.test_project_structure`
Expected: PASS

**Step 5: Commit**

```bash
git add .
git commit -m "chore: bootstrap godot project structure"
```
