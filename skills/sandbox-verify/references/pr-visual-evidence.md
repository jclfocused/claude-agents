# UI/UX evidence in every PR

Applies to all projects and all visible or interaction changes. Keep the repository's PR template and add the comparison section below. This supplements real-browser QA; it does not replace it. Both the screenshots and the QA verdict carry the [UX/UI review](ux-ui-review.md): inspect the After shots against that rubric at 1440 and 390, not only for whether the change rendered.

1. Capture **Before** from the base branch or a verified unchanged deployment and **After** from the PR branch. Record the source commit, route, state, viewport and theme in the local QA receipt. Never label another after image as before. If a baseline cannot be captured, explain the specific gap rather than inventing evidence.
2. Use the same viewport, theme, route and representative demo data. Show the meaningful changed region; include a mobile pair when responsive behavior changes. Wait for loading and animations to settle, and inspect every image. Keep credentials, full API keys and customer data out of captures.
3. Follow the existing template: the problem, what changed, what to test, and why. Avoid model names, review-process narration and exhaustive micro-change lists.
4. Upload screenshots as real GitHub attachments and place a **Before / After table in the PR description**. Do not use local paths or invent attachment URLs. Keep screenshots out of application source unless the repository explicitly stores review evidence there. Preserve any existing comment draft; uploading through an empty composer does not require posting a comment.
5. Link the stable **branch preview**, not a commit deployment. Open the PR in the browser and confirm all images render.
6. After every UI/UX revision, including review fixes, refresh the affected **After screenshots and usage videos** from the updated preview. Keep the original Before evidence unless the baseline changes. Replace stale attachments in the PR description; inspect the images and replay the clips on the rendered PR before review. Record the capture's source commit and what it supersedes. Unchanged screens/flows and docs-only commits do not require recapture.

```markdown
## UI comparison

| Before | After |
| --- | --- |
| ![Before: screen and state](uploaded-before-url) | ![After: screen and state](uploaded-after-url) |

Preview: <stable-branch-preview-url>
```

For additional routes or mobile states, add another labelled pair or a collapsible section. Each PR shows its own change, not an unrelated full redesign.

## Short flow recordings

Use the separate `app-usage-video` skill for naturally paced cursor movement, clicks, typing and readable pauses.

When clicks, navigation, keyboard focus or transitions explain the change better, add a short **10–30 second real-browser clip** alongside the screenshots. Record the actual controls and resulting state. Show Before and After as separately labelled clips for a changed flow when useful; do not present a single after clip as a comparison. Screenshots remain mandatory.

Use the `browser` skill first. BetterWright supports `recording.start`, `recording.status` and `recording.stop`; stop flushes the file. If a demonstrated tool limitation requires Playwright, use its browser-context recording or an owned CDP target and preserve the fallback reason. Begin capture after sign-in; never record credential entry. Keep a readable cursor/click indicator if useful, without altering application behavior. Prefer broadly playable MP4; conversion may change encoding, not the recorded outcome.

Keep clips focused and silent unless narration is requested. Upload to GitHub through the same attachment flow, embed the returned link, and verify playback and duration in the rendered PR. Record only authorized preview/demo actions; do not make real purchases, revoke customer keys or mutate production data to produce a demo.

Sources: [Playwright video capture](https://playwright.dev/docs/videos), [GitHub attachments and video formats](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/attaching-files). Verified 12 October 2026.
