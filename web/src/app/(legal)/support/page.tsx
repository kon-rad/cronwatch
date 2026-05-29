import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Support — Cronwatch",
  description:
    "Get help with Cronwatch — contact the team, troubleshoot sign-in and subscriptions, request features, and report bugs.",
};

const SUPPORT_EMAIL = "synducer@gmail.com";

export default function SupportPage() {
  return (
    <>
      <p className="legal-eyebrow">Support</p>
      <h1>Support</h1>
      <p className="legal-meta">We&apos;re a small team — replies come from a human.</p>

      <p className="legal-lede">
        Need a hand with Cronwatch? Email{" "}
        <a href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a> and we&apos;ll get
        back to you, usually within one to two business days.
      </p>

      <h2>Contact</h2>
      <p>
        The fastest way to reach us is email:{" "}
        <a href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a>. Please include
        your account email, the device and iOS version you&apos;re on, and a short
        description of what happened. Screenshots help.
      </p>

      <h2>Common questions</h2>

      <h3>I can&apos;t sign in</h3>
      <p>
        Cronwatch uses Sign in with Apple and Sign in with Google. If sign-in
        fails, make sure you&apos;re online and that your Apple ID / Google
        account is in good standing. If it still won&apos;t work, email us with
        the provider you&apos;re using and any error message you see.
      </p>

      <h3>How do I cancel my subscription?</h3>
      <p>
        Subscriptions are billed through the App Store. Open the Settings app on
        your iPhone, tap your name, then <strong>Subscriptions</strong>, and
        cancel Cronwatch there. Cancellation takes effect at the end of the
        current billing period. Refund requests are handled by Apple under the
        App Store&apos;s refund policy.
      </p>

      <h3>How do I delete my account and data?</h3>
      <p>
        In the app, go to the <strong>Profile</strong> tab and tap{" "}
        <strong>Delete account</strong>. This removes your entries and identity
        from our active systems. If you&apos;d prefer we handle it, email{" "}
        <a href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a> from the address
        on your account.
      </p>

      <h3>Can I export my entries?</h3>
      <p>
        Yes. Email <a href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a> and
        we&apos;ll send you a machine-readable export of your data.
      </p>

      <h3>A voice capture transcribed wrong</h3>
      <p>
        Transcription and structured-entry extraction aren&apos;t perfect. You
        can edit any entry directly in the app — tap it, fix the category,
        note, or times, and save. If a specific phrase consistently misfires,
        send us an example so we can improve it.
      </p>

      <h2>Bug reports</h2>
      <p>
        Found something broken? Email{" "}
        <a href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a> with:
      </p>
      <ul>
        <li>What you were doing when it happened</li>
        <li>What you expected vs. what actually happened</li>
        <li>Your iPhone model and iOS version</li>
        <li>The app version (Profile → About)</li>
        <li>A screenshot or screen recording, if you can</li>
      </ul>

      <h2>Feature requests</h2>
      <p>
        We read every one. Email{" "}
        <a href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a> with what
        you&apos;re trying to do and how you&apos;d use it. Concrete use cases
        help us prioritize.
      </p>

      <h2>Privacy and security</h2>
      <p>
        For privacy questions, data requests, or to report a security issue,
        email <a href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a>. Details
        on what we collect and how we handle it are in our{" "}
        <a href="/privacy">Privacy Policy</a>.
      </p>
    </>
  );
}
