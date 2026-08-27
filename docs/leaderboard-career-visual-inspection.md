# Leaderboard and Career Dossier Visual Inspection

## Career Signal — Landscape 1280×720

**PASS WITH POLISH FIX REQUIRED.** The three-page tab rail is clear, the active Career Signal page reads correctly, the callsign editor has adequate touch and keyboard targets, and the three-series weapon chart has strong contrast, exact axis labels, point markers, legend, and a selected-run tooltip. The chart and footer remain inside the viewport. The five local ranking rows are legible through score, but their weapon suffix is clipped by the narrow left column; the implementation will switch local rows to a compact tier/score template while retaining the full template on the wide global page.

## Career Signal — Portrait 720×1280

**PASS.** The tabs, callsign row, mode buttons, 608×354 logical chart, tooltip, five local rows, and persistent Retry/Title actions fit inside the safe area without overlap. The chart preserves numerical readability and touch-scale controls. The vertical hierarchy is consistent with the existing dossier rather than becoming a separate dashboard.

## Global Network — Landscape 1280×720

**PASS.** The active network state, personal-rank banner, refresh action, and ten deterministic rows read cleanly at desktop scale. Rank, callsign, highest combo tier, score, and preferred weapon preserve a stable scan order with no clipping.

## Global Network — Portrait 720×1280

**PASS.** Ten full ranking rows fit above the persistent actions with comfortable vertical separation. The status and refresh controls remain independent, the active tab is unambiguous, and the full ranking tuple remains legible without horizontal overflow.

## Landscape Local-Row Polish Recheck

**PASS.** The local ranking now uses its dedicated compact template (`rank / callsign / tier / score`), so all five entries fit the 330-pixel card without clipping. Preferred weapon remains available in the full-width global table and in the chart tooltip.
