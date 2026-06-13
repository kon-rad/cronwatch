import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Privacy Policy — Cronwatch",
  description:
    "How Cronwatch collects, uses, and protects your data — voice captures, time entries, account info, and the third-party services we rely on.",
};

const EFFECTIVE_DATE = "May 14, 2026";

export default function PrivacyPage() {
  return (
    <>
      <p className="legal-eyebrow">Privacy</p>
      <h1>Privacy Policy</h1>
      <p className="legal-meta">Effective {EFFECTIVE_DATE}</p>

      <p className="legal-lede">
        Cronwatch is a voice-first time tracker. This policy explains what we
        collect, why we collect it, who we share it with, and the choices you
        have. We try to keep it plain.
      </p>

      <h2>Who we are</h2>
      <p>
        Cronwatch is operated by the Cronwatch team (&quot;Cronwatch&quot;,
        &quot;we&quot;, &quot;us&quot;). If you need to reach us about this
        policy, email{" "}
        <a href="mailto:synducer@gmail.com">synducer@gmail.com</a>.
      </p>

      <h2>What we collect</h2>

      <h3>Account information</h3>
      <p>
        When you sign in with Google or Apple, we receive your name, email
        address, and a stable user identifier from the sign-in provider. We
        store this in Firebase Authentication and Cloud Firestore so we can
        identify your account on return visits.
      </p>

      <h3>Time entries you create</h3>
      <p>
        Every entry you capture is stored in Cloud Firestore under your user
        account. An entry typically contains:
      </p>
      <ul>
        <li>A category and a short note</li>
        <li>A start time and end time (in UTC)</li>
        <li>The transcript of what you said, if you used voice capture</li>
        <li>Metadata such as when the entry was created and the capture source</li>
      </ul>

      <h3>Voice recordings and AI processing</h3>
      <p>
        When you capture by voice, your audio recording is sent to{" "}
        <a href="https://together.ai" target="_blank" rel="noreferrer">
          Together AI
        </a>{" "}
        and transcribed to text with the Whisper speech-to-text model. The
        resulting text (along with the capture time and your time zone) is then
        processed by an open-weights language model — also at Together AI — to
        extract a structured entry (category, note, time range). Typed entries
        skip transcription and are sent to Together AI for the same structuring
        step.
      </p>
      <p>
        The app discloses this and asks for your permission in-app before any
        capture is sent. We do not retain raw audio in our own systems by
        default; if you opt into raw-audio storage in a future version, the clip
        is stored in Firebase Storage scoped to your account.
      </p>

      <h3>Subscription and payment information</h3>
      <p>
        Subscriptions are managed by{" "}
        <a href="https://www.revenuecat.com" target="_blank" rel="noreferrer">
          RevenueCat
        </a>{" "}
        on top of Apple&apos;s App Store. We receive your subscription status
        and entitlement, but we never see your full payment details — those
        stay with Apple.
      </p>

      <h3>Device and diagnostic information</h3>
      <p>
        We may collect basic diagnostic data — app version, OS version, crash
        reports, and anonymized usage events — to keep the app reliable. We do
        not sell this information.
      </p>

      <h2>Why we collect it</h2>
      <ul>
        <li>To run the app and let you sign in, capture entries, and review your day.</li>
        <li>To turn your voice into structured entries via transcription and language models.</li>
        <li>To manage your subscription and entitlements.</li>
        <li>To diagnose crashes and improve the experience.</li>
      </ul>

      <h2>How we share data with sub-processors</h2>
      <p>
        We use a small number of third-party services to operate Cronwatch.
        Each receives only the data it needs to do its job:
      </p>
      <ul>
        <li>
          <strong>Google Firebase</strong> — authentication, database, file
          storage, and crash reporting.
        </li>
        <li>
          <strong>Together AI</strong> — speech-to-text transcription of voice
          captures (audio is sent only when you use voice capture), and language
          model processing of the resulting text to produce a structured entry.
        </li>
        <li>
          <strong>RevenueCat &amp; Apple</strong> — subscription billing and
          entitlement.
        </li>
        <li>
          <strong>Google &amp; Apple Sign-In</strong> — identity verification
          when you sign in.
        </li>
      </ul>
      <p>
        We do not sell your data, and we do not share it with advertisers or
        data brokers. Each sub-processor processes your data only to provide its
        service to Cronwatch, under its own terms and a data processing
        agreement, and is required to protect your data to a standard at least
        equal to that described in this policy.
      </p>

      <h2>Where data is stored</h2>
      <p>
        Your entries and account information live in Google&apos;s Firebase
        infrastructure. Data may be processed in the United States and other
        regions where Google operates. Audio transcription and language model
        processing happen in the regions operated by Together AI.
      </p>

      <h2>How long we keep it</h2>
      <p>
        We keep your account and entries for as long as your account is active.
        If you delete your account, we remove your entries from our active
        systems within 30 days. Backups roll off on their normal cycle.
      </p>

      <h2>Your choices</h2>
      <ul>
        <li>
          <strong>Access &amp; export.</strong> You can view your entries in the
          app at any time. Email{" "}
          <a href="mailto:synducer@gmail.com">synducer@gmail.com</a> for a
          machine-readable export.
        </li>
        <li>
          <strong>Correction.</strong> Edit any entry directly in the app, or
          email us if you need help.
        </li>
        <li>
          <strong>Deletion.</strong> Tap &quot;Delete account&quot; in the
          Profile tab, or email us. This removes your entries and identity from
          our active systems.
        </li>
        <li>
          <strong>Withdraw consent.</strong> Sign out and stop using the app at
          any time. Subscriptions can be cancelled in the App Store.
        </li>
      </ul>

      <h2>Children</h2>
      <p>
        Cronwatch is not directed at children under 13 (or the equivalent age in
        your jurisdiction). We do not knowingly collect personal information
        from children. If you believe a child has provided us information,
        contact us and we will delete it.
      </p>

      <h2>Security</h2>
      <p>
        We rely on industry-standard practices: TLS in transit, encryption at
        rest in Firebase, and Firestore security rules that scope every read and
        write to the signed-in user. No system is perfect — if you suspect a
        security issue, email{" "}
        <a href="mailto:synducer@gmail.com">synducer@gmail.com</a>.
      </p>

      <h2>Changes to this policy</h2>
      <p>
        If we make material changes, we will update the effective date at the
        top of this page and, where appropriate, notify you in the app. Your
        continued use of Cronwatch after the change means you accept the
        revised policy.
      </p>

      <h2>Contact</h2>
      <p>
        Questions, requests, or concerns:{" "}
        <a href="mailto:synducer@gmail.com">synducer@gmail.com</a>.
      </p>
    </>
  );
}
