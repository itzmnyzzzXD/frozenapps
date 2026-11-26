# Agent Playbooks

1. proof-of-work: sync and verify the branch; hash files before and after; show git diff --stat; never present unchanged files; no TEST pasted means not done.
2. build-doctor: read the real log; classify the error; make the minimal root-cause fix; rerun; loop; one commit per fix; stop and report when you cannot verify.
3. web-to-swiftui-port: read the whole source; list its props; mark demo-only behavior versus real behavior; convert Tailwind to points; map motion to SwiftUI animations; convert to monochrome; add the Reduce Motion branch and a #Preview per state; run the TEST.
4. glsl-to-msl: atan2, dfdx/dfdy, sample(), y flip, full float precision, uniform alignment, premultiplied alpha, real compile before claiming done.
5. monochrome-audit: run scripts/check-monochrome.sh; fix every leak; rerun until clean; paste the output.
6. anti-slop-review: score each screen 1 to 5 on hierarchy, rhythm, token consistency, legibility, motion purpose and restraint; fix anything under 4; re-score.
