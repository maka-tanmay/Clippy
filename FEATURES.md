# Feature Plan: What the Original Clippy Lacked

The 1997 Office Assistant failed for specific, well-documented reasons. Each section
below names one area where the original lagged, explains the failure, and proposes the
modern feature that fixes it. A prioritized roadmap follows at the end.

---

## 1. Intelligence — it couldn't understand you

**Then:** Clippy matched keywords against a static help index. Typing a question in your
own words usually surfaced an unrelated help article. Its famous "It looks like you're
writing a letter" heuristic fired on almost any text starting with "Dear".

**New features:**

- **Conversational assistant** — multi-turn natural-language chat backed by an LLM, so
  "make this table stop breaking across pages" gets a real answer, not a help-index link.
- **Follow-up context** — the conversation remembers what "it" and "that" refer to across
  turns, so users don't restate their problem.
- **Grounded answers** — responses cite the actual setting/menu path in the user's app
  version instead of generic instructions.

## 2. Agency — it could only point at help articles

**Then:** Even when Clippy correctly guessed your intent, all it could do was open
documentation. The user still had to do everything manually.

**New features:**

- **"Do it for me" actions** — every suggestion ships with an apply button: format the
  letter, fix the numbering, build the mail merge, rename the files.
- **Action preview and undo** — before applying, show a diff/preview of what will change;
  after applying, one click reverts it. Trust comes from reversibility.
- **Task automation** — record or describe a repetitive task ("do this to every file in
  the folder") and let Clippy execute it step by step with progress shown.

## 3. Respect for attention — it interrupted constantly

**Then:** This was the #1 complaint. Clippy popped up uninvited, stole focus, re-offered
tips it had already been told to dismiss, and had no concept of "not now".

**New features:**

- **Interruption budget** — proactive suggestions are rate-limited; if the user dismisses
  two in a row, Clippy goes quiet and waits to be summoned.
- **Quiet hours / do-not-disturb** — manual toggle plus automatic silence during
  presentations, screen sharing, and full-screen apps.
- **Learn from dismissals** — a dismissed suggestion type is never re-offered for that
  document; three dismissals mute that suggestion category globally until re-enabled.
- **Summon-first design** — a global hotkey and a small idle avatar are the primary entry
  points. Proactive help is the exception, not the default.

## 4. Memory & personalization — it treated every day like your first

**Then:** Clippy had no user model. It offered the same letter tip to a novice and to
someone on their ten-thousandth letter, forever.

**New features:**

- **Preference memory** — remembers tone, verbosity, favorite actions, and which
  suggestion categories the user actually accepts.
- **Skill-level adaptation** — stops explaining features the user demonstrably already
  uses; surfaces genuinely unknown ones instead.
- **Per-project context** — remembers facts the user tells it ("this report uses UK
  spelling") and applies them within that project only.

## 5. Performance — it made Office lag

**Then:** The Office Assistant's always-resident animation and agent runtime consumed
meaningful CPU and RAM on late-90s machines; many users disabled it purely because
Office felt faster without it.

**New features:**

- **Lazy everything** — the assistant process starts suspended and loads models/assets
  only on first summon; idle cost is a static sprite and near-zero CPU.
- **Hard performance budget in CI** — regression tests fail the build if idle CPU, memory
  footprint, or summon-to-first-response latency exceed published budgets.
- **On-device small model + cloud escalation** — quick intents (rename, format, define)
  resolve locally in milliseconds; only complex requests escalate to a larger model, with
  a visible indicator.
- **Animation off-switch that sticks** — reduced-motion mode with a static avatar,
  honored globally and persisted (the original's "hide" famously didn't stay hidden).

## 6. Privacy & trust — it watched everything with no controls

**Then:** Clippy monitored your typing to trigger tips, with no visibility or control
over what was observed.

**New features:**

- **On-device by default** — document content never leaves the machine unless the user
  explicitly enables cloud answers, per app or per document.
- **Activity transparency panel** — a log of what Clippy observed, suggested, and did,
  with per-entry delete.
- **Incognito documents** — mark a document as never-observed; Clippy is blind to it and
  says so if summoned there.

## 7. Reach — it lived only inside Office on Windows

**Then:** Clippy was welded to Microsoft Office. No other apps, no other platforms, no
other languages beyond localized help text.

**New features:**

- **OS-wide companion** — one assistant across the desktop (Windows/macOS/Linux) that
  understands the frontmost app, not just one office suite.
- **Browser extension bridge** — the same assistant, memory, and hotkey inside the
  browser.
- **Multilingual conversation** — ask in any language, get answers in that language,
  including mixed-language documents.

## 8. Accessibility — it was decoration for the sighted mouse user

**Then:** The assistant was an animated bitmap: invisible to screen readers, unusable
from the keyboard, and its motion could not be reduced, only disabled entirely.

**New features:**

- **Full keyboard and screen-reader support** — every suggestion and action reachable via
  hotkey and properly announced (ARIA/UIA).
- **Voice in, voice out** — optional speech interaction for hands-free or low-vision use.
- **Reduced-motion and high-contrast modes** — first-class themes, not an afterthought.

## 9. Extensibility — it was a sealed box

**Then:** Users and developers could not teach Clippy anything or extend it (beyond
swapping the character art).

**New features:**

- **Skill plugin API** — third parties add capabilities ("summon Clippy in our app to
  file an expense report") through a sandboxed, permissioned plugin system.
- **Custom characters** — community-made avatars with a documented sprite/animation
  format; ship the classic cast (Clippit, Rover, Merlin, Links) as the default pack.
- **User-defined shortcuts** — save any conversation outcome as a reusable one-click
  action ("apply my report formatting").

## 10. Feedback loop — it never knew it was failing

**Then:** Microsoft learned Clippy was hated from the press, not from the product. There
was no in-product signal for "this suggestion was wrong".

**New features:**

- **Per-suggestion thumbs up/down** — one-tap feedback wired directly into the
  suggestion ranking, so bad suggestion types die quickly.
- **Opt-in anonymous telemetry** — aggregate accept/dismiss rates per suggestion
  category, off by default, transparent about payload.

---

## Roadmap

| Version | Theme | Features |
|---------|-------|----------|
| **v0.1** | Summonable & smart | Global hotkey summon, conversational chat (on-device small model), classic Clippit avatar, reduced-motion mode, performance budgets in CI |
| **v0.2** | Useful | "Do it for me" actions with preview + undo for the frontmost app, grounded answers, per-suggestion feedback |
| **v0.3** | Polite | Interruption budget, learn-from-dismissals, quiet hours, activity transparency panel |
| **v0.4** | Personal | Preference memory, skill-level adaptation, per-project context, incognito documents |
| **v1.0** | Everywhere | Cross-platform companion, browser extension, voice I/O, skill plugin API, custom character packs |

The ordering is deliberate: the original Clippy's fate proves that *polite and fast* must
ship before *proactive*, and *useful* must ship before *everywhere*.
