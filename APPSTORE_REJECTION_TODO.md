# App Store Rejection — Submission b39b0558 (v1.0)

## CURRENT issue (review June 6, 2026) — Guideline 5.1.1(i) / 5.1.2(i): Privacy — Data Collection & Use

Apple flagged that the app shares personal data with a third-party AI service without
disclosing what is sent, naming who it goes to, and getting permission **in-app** before
sending. (Privacy-policy disclosure alone is not sufficient.)

### Reality of our data flows (so the reply is truthful)
- **Every capture** (voice *or* typed) sends the transcript **text** to **Together AI**
  (Llama-3.3-70B) for structuring into time entries.
- **Voice capture** additionally sends the **audio** to **Together AI** (Whisper) for
  transcription. This is now the fixed default — transcription is no longer on-device and
  there is no in-app provider picker. Deepgram is no longer in the shipping path.
- **Profile reports** send aggregated time-entry data + goals + custom prompt to Together AI.
- We therefore **cannot** tell Apple "no third-party AI is used." Together AI is always
  involved — for both transcription and structuring.

### Fix — DONE in code (needs new build)
- [x] Added one-time in-app AI data consent disclosure shown **before the first capture is
      sent** (`AIDataConsentView.swift`) — discloses what is sent, names Together AI,
      links the privacy policy, requires an explicit "Agree & Continue".
- [x] Consent persisted in `AIConsentStore.swift` (version bumped to 2 since the disclosure
      now states audio is always sent to Together AI); gates both voice (`onPressIn`) and
      typed (`onSaveTyped`) capture in `CaptureView.swift`.
- [x] Default transcription set to Together AI Whisper; on-device default and the in-app
      provider picker (Settings → Transcription) removed.
- [x] Build verified: `xcodebuild ... -sdk iphonesimulator build` → **BUILD SUCCEEDED**.
- [x] Privacy policy updated (`web/src/app/(legal)/privacy/page.tsx`): audio sent to Together
      AI for transcription, in-app permission, and an "equal protection" sub-processor
      statement (Apple req #4).

### Still TODO before resubmitting
- [ ] Deploy the updated privacy policy site so `https://cronwatch.xyz/privacy` is live.
- [ ] **Verify sub-processor terms** before relying on the "equal protection" wording —
      confirm Together AI's API data-handling terms actually match the claim.
- [ ] Confirm the new build number in App Store Connect and update the reply text to match.
- [ ] Archive & upload the new build (consent flow + Together Whisper default) in App Store Connect.
- [ ] Reply to App Review with the message in `docs/appstore-reply-5.1.1.md` (below).
- [ ] Resubmit for review.

### Optional hardening (not required, strengthens the case)
- [ ] Add a "Data & AI" row in Profile linking the same disclosure + privacy policy so the
      user can review/revoke at any time (`AIConsentStore.revoke()` already exists).

---

## PREVIOUS issues (already resolved metadata-only) — keep for reference

### Guideline 2.3.2: IAP Promotional Image
- [ ] Delete the promotional image from BOTH IAP products, OR replace with two unique
      1024×1024 graphics (no screenshots, large text, no prices).

### Guideline 2.3.7: Screenshots reference price
- [ ] Remove every product-page screenshot showing price / "free trial" / "price of a
      coffee"; replace with feature screenshots. Check all device sizes & localizations.
- The in-app paywall MUST keep showing prices — only static marketing assets are the problem.
