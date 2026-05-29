import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Terms of Service — Cronwatch",
  description:
    "The terms that govern your use of Cronwatch — accounts, subscriptions, acceptable use, and the usual legal scaffolding.",
};

const EFFECTIVE_DATE = "May 14, 2026";

export default function TermsPage() {
  return (
    <>
      <p className="legal-eyebrow">Terms</p>
      <h1>Terms of Service</h1>
      <p className="legal-meta">Effective {EFFECTIVE_DATE}</p>

      <p className="legal-lede">
        These terms govern your use of Cronwatch — the iOS app and the
        cronwatch.xyz website. By creating an account or using the app, you
        agree to these terms. If you do not agree, please do not use Cronwatch.
      </p>

      <h2>1. The service</h2>
      <p>
        Cronwatch is a voice-first time tracker. You capture short voice or
        text notes, we transcribe and structure them, and the result is stored
        on your account as a time entry. We may add, change, or remove features
        over time.
      </p>

      <h2>2. Your account</h2>
      <p>
        You need an account to use Cronwatch. You can sign in with Google or
        Apple. You are responsible for activity on your account and for keeping
        access to your sign-in provider secure. Let us know promptly at{" "}
        <a href="mailto:synducer@gmail.com">synducer@gmail.com</a> if you
        suspect unauthorized use.
      </p>
      <p>
        You must be at least 13 years old, or the minimum age required in your
        country, to use Cronwatch.
      </p>

      <h2>3. Subscriptions and billing</h2>
      <p>
        Cronwatch offers paid subscriptions purchased through the Apple App
        Store and managed via{" "}
        <a href="https://www.revenuecat.com" target="_blank" rel="noreferrer">
          RevenueCat
        </a>
        . Current plans and prices are shown in the app. Subscriptions renew
        automatically until cancelled. You can manage or cancel your
        subscription at any time in your App Store account settings; cancellation
        takes effect at the end of the current billing period.
      </p>
      <p>
        Refunds are handled by Apple under the App Store&apos;s refund policy,
        not by us.
      </p>

      <h2>4. Your content</h2>
      <p>
        Your entries, transcripts, and any voice clips you capture are yours.
        You grant us a limited, non-exclusive license to host, transmit, and
        process them solely so we can provide the service to you — including
        sending audio to our transcription provider and sending text to our
        language model provider to produce structured entries. We don&apos;t use
        your content to train third-party general-purpose models. We treat your
        content as confidential, consistent with our{" "}
        <a href="/privacy">Privacy Policy</a>.
      </p>

      <h2>5. Acceptable use</h2>
      <p>You agree not to use Cronwatch to:</p>
      <ul>
        <li>Break the law or infringe someone else&apos;s rights.</li>
        <li>
          Upload content that is illegal, harmful, abusive, harassing, or
          contains malware.
        </li>
        <li>
          Reverse engineer, scrape, or attempt to disrupt the service or its
          infrastructure.
        </li>
        <li>
          Resell or repackage the service without our written permission.
        </li>
        <li>
          Use the service in a way that exceeds reasonable usage limits or
          imposes unreasonable cost on us or our providers.
        </li>
      </ul>
      <p>
        We may suspend or terminate accounts that violate these rules. Where
        feasible, we will give notice and an opportunity to fix the issue.
      </p>

      <h2>6. Third-party services</h2>
      <p>
        Cronwatch depends on third-party services, including Google Firebase,
        Deepgram, Together AI, RevenueCat, and Apple. Their performance is
        outside our direct control. Your use of those services is also subject
        to their own terms.
      </p>

      <h2>7. Intellectual property</h2>
      <p>
        Cronwatch&apos;s name, logo, app, and website are protected by
        copyright, trademark, and other laws. We grant you a personal,
        non-exclusive, non-transferable, revocable license to use the app for
        its intended purpose. Open-source components are licensed under their
        respective licenses; see the project repository for details.
      </p>

      <h2>8. Disclaimers</h2>
      <p>
        Cronwatch is provided <strong>&quot;as is&quot;</strong> and{" "}
        <strong>&quot;as available&quot;</strong>. To the maximum extent
        permitted by law, we disclaim all warranties, express or implied,
        including warranties of merchantability, fitness for a particular
        purpose, and non-infringement. We do not warrant that transcription or
        language-model output will be accurate, complete, or fit for any
        particular use. Do not rely on Cronwatch as your sole record where
        accuracy is critical (for example, regulated billing).
      </p>

      <h2>9. Limitation of liability</h2>
      <p>
        To the maximum extent permitted by law, Cronwatch and its operators are
        not liable for indirect, incidental, consequential, special, or
        punitive damages, or for lost profits, revenues, data, or goodwill,
        even if we have been advised of the possibility. Our total liability
        for any claim relating to the service is limited to the greater of (a)
        the amount you paid us for the service in the twelve months before the
        claim, or (b) USD $50.
      </p>

      <h2>10. Termination</h2>
      <p>
        You can stop using Cronwatch at any time, and you can delete your
        account from the Profile tab. We may suspend or terminate your access
        if you breach these terms, if required by law, or if continuing the
        service is no longer commercially viable. On termination, your right
        to use the app ends; sections that by their nature should survive
        (ownership, disclaimers, liability, dispute resolution) will survive.
      </p>

      <h2>11. Changes to these terms</h2>
      <p>
        We may update these terms from time to time. If the changes are
        material, we will update the effective date at the top of this page
        and, where appropriate, notify you in the app. Continued use of
        Cronwatch after a change means you accept the revised terms.
      </p>

      <h2>12. Governing law</h2>
      <p>
        These terms are governed by the laws of the jurisdiction in which the
        Cronwatch operating entity is based, without regard to its conflict-of-laws
        rules. The parties submit to the exclusive jurisdiction of the courts
        located there, unless mandatory local law requires otherwise.
      </p>

      <h2>13. Contact</h2>
      <p>
        Questions about these terms:{" "}
        <a href="mailto:synducer@gmail.com">synducer@gmail.com</a>.
      </p>
    </>
  );
}
