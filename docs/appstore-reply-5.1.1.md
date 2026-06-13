# Reply to App Review — Submission b39b0558 (Guideline 5.1.1(i) / 5.1.2(i))

_Paste into App Store Connect → Resolution Center. Resubmit with the new build
that contains the consent flow, and make sure the updated privacy policy is live first._

---

Hello,

Thank you for the detailed feedback. You are correct that Cronwatch sends user
data to third-party AI services, and we have updated the app to disclose this,
identify the recipients, and obtain the user's permission before any data is
sent. Details below.

**What data is sent, and to whom**

- For every capture (voice or typed), the text of the entry — along with the
  capture time and time zone — is sent to **Together AI**, which runs an
  open-weights language model to turn it into a structured time entry (category,
  note, start/end time).
- For **voice** capture, the audio recording is also sent to **Together AI**,
  which transcribes it to text with the Whisper speech-to-text model before the
  structuring step above. Typed captures send only text.
- We do not sell user data or share it with advertisers or data brokers.

**Changes in this build (in-app permission before sending)**

We added a one-time disclosure screen that appears **before the user's first
capture is sent**. It:

1. Explains exactly what data is sent (the capture text, plus the audio
   recording for voice captures);
2. Names the third-party service that receives it (Together AI);
3. Links to our full privacy policy; and
4. Requires the user to tap "Agree & Continue" before any data is shared. The
   user can decline, and nothing is sent.

This gate applies to both voice and typed capture.

**Privacy policy**

Our privacy policy identifies what data we collect, how we collect it, and every
use of that data, including the third-party AI service it is shared with
(Together AI) and that each sub-processor is contractually required to protect
the data to a standard at least equal to our own and to use it only to provide
its service to Cronwatch:

https://cronwatch.xyz/privacy

We believe these changes fully address guidelines 5.1.1(i) and 5.1.2(i). Please
let us know if anything else would help, and thank you for your time.

Best regards,
Konrad Gnat
