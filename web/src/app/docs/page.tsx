import type { Metadata } from "next";
import Link from "next/link";
import { CopyButton } from "@/components/copy-button";

export const metadata: Metadata = {
  title: "API Docs — Cronwatch",
  description:
    "Developer documentation for the Cronwatch API. Give any agent or script read-only access to your time-tracking entries and weekly goals with an API key.",
};

const BASE_URL = "https://api.cronwatch.xyz";

const SKILL_URL = "/skill.md";

const AGENT_PROMPT = `You have access to the user's Cronwatch time-tracking data.
Base URL: https://api.cronwatch.xyz
Authentication: send header  X-Api-Key: cw_your_key_here

Endpoints:
  GET /v1/me                          — weekly goals & profile
  GET /v1/entries?from=ISO&to=ISO     — time entries in a date range

When the user asks about their time, habits, schedule, or goal
progress, call the relevant endpoint and reason over the results.
Times are ISO 8601 (UTC). Never log or echo the API key.`;

export default function DocsPage() {
  return (
    <div>
      {/* Header */}
      <p className="font-mono text-[12px] uppercase tracking-[0.12em] text-amber-deep mb-4">
        Developer API
      </p>
      <h1 className="text-[clamp(34px,5vw,48px)] font-semibold tracking-[-0.025em] leading-[1.05] m-0 mb-5">
        Cronwatch API
      </h1>
      <p className="text-[18px] text-ink-muted leading-[1.6] m-0 max-w-[62ch]">
        Give any agent or script read-only access to your time-tracking data.
        Create an API key in the app, send it as a header, and query your
        structured time entries and weekly goals over HTTPS.
      </p>

      {/* At a glance */}
      <div className="grid sm:grid-cols-3 gap-3 mt-10">
        <Glance label="Base URL" value="api.cronwatch.xyz" />
        <Glance label="Auth" value="X-Api-Key header" />
        <Glance label="Access" value="Read-only" />
      </div>

      {/* Quick start */}
      <Section id="quickstart" title="Quick start">
        <ol className="list-none p-0 m-0 space-y-6">
          <Step n={1} title="Create an API key">
            Open Cronwatch on iOS → <strong>Profile</strong> →{" "}
            <strong>API Keys</strong> → tap <strong>+</strong>. Name it (e.g.
            &ldquo;My Claude Agent&rdquo;) and tap <strong>Create</strong>. The
            full key — it starts with{" "}
            <code className="cw-code">cw_</code> — is shown{" "}
            <strong>once</strong>. Copy it somewhere safe; it can&apos;t be
            recovered. API keys require an active subscription.
          </Step>
          <Step n={2} title="Send your first request">
            Pass the key in the <code className="cw-code">X-Api-Key</code>{" "}
            header on every request:
            <CodeBlock
              className="mt-4"
              code={`curl ${BASE_URL}/v1/me \\
  -H "X-Api-Key: cw_your_key_here"`}
            />
          </Step>
          <Step n={3} title="Query your entries">
            Ask for any date range and reason over the structured blocks that
            come back — category, note, start, end.
          </Step>
        </ol>
      </Section>

      {/* Authentication */}
      <Section id="auth" title="Authentication">
        <p className="cw-p">
          Every request must include your secret key in the{" "}
          <code className="cw-code">X-Api-Key</code> header. Keys begin with{" "}
          <code className="cw-code">cw_</code>. There are no scopes — a key
          grants read-only access to the entries and profile of the account
          that created it, and nothing else.
        </p>
        <CodeBlock code={`X-Api-Key: cw_your_key_here`} />
        <ul className="cw-list">
          <li>
            Keep keys secret. Store them in an environment variable or secrets
            manager — never commit them to source control.
          </li>
          <li>
            Lost or leaked a key? In the app, open the key&apos;s menu and tap{" "}
            <strong>Refresh</strong> (rotates it) or <strong>Delete</strong>.
            The old value stops working immediately.
          </li>
          <li>
            A missing or malformed key returns{" "}
            <code className="cw-code">401 Unauthorized</code>.
          </li>
        </ul>
      </Section>

      {/* Endpoints */}
      <Section id="endpoints" title="Endpoints">
        {/* /v1/entries */}
        <Endpoint method="GET" path="/v1/entries" />
        <p className="cw-p">
          List time entries that overlap a date window, ordered by start time
          ascending.
        </p>

        <h3 className="cw-h3">Query parameters</h3>
        <ParamTable
          rows={[
            ["from", "ISO 8601", "Window start, compared against each entry's start time. Default: 7 days ago."],
            ["to", "ISO 8601", "Window end. Default: now."],
            ["limit", "integer", "Max entries to return, 1–500. Default: 200."],
          ]}
        />
        <p className="cw-note">
          Entries that begin just before <code className="cw-code">from</code>{" "}
          but end inside the window (e.g. overnight sleep) are included.
        </p>

        <h3 className="cw-h3">Example request</h3>
        <CodeBlock
          code={`curl ${BASE_URL}/v1/entries \\
  -H "X-Api-Key: cw_your_key_here" \\
  -G \\
  --data-urlencode "from=2026-01-01T00:00:00Z" \\
  --data-urlencode "to=2026-01-31T23:59:59Z" \\
  --data-urlencode "limit=500"`}
        />

        <h3 className="cw-h3">Example response</h3>
        <CodeBlock
          lang="json"
          code={`{
  "entries": [
    {
      "id": "c_1737014400000_a1b2c3",
      "captureId": "c_1737014400000_a1b2c3",
      "category": "deep",
      "note": "API architecture review",
      "startTime": "2026-01-16T09:00:00.000Z",
      "endTime":   "2026-01-16T10:30:00.000Z",
      "source": "voice",
      "transcript": "Spent ninety minutes on the API architecture…",
      "createdAt": "2026-01-16T10:31:22.000Z"
    }
  ],
  "count": 1
}`}
        />

        <h3 className="cw-h3">Entry fields</h3>
        <ParamTable
          rows={[
            ["id", "string", "Unique entry identifier."],
            ["captureId", "string", "ID of the voice capture this entry came from. Falls back to id."],
            ["category", "string", "Activity category, e.g. deep, admin, rest."],
            ["note", "string", "Short human-readable summary of the block."],
            ["startTime", "ISO 8601", "When the block started (UTC)."],
            ["endTime", "ISO 8601", "When the block ended (UTC)."],
            ["source", "string", "How the entry was created, e.g. voice."],
            ["transcript", "string | null", "Original voice transcript, when available."],
            ["createdAt", "ISO 8601", "When the entry was recorded."],
          ]}
        />

        {/* /v1/me */}
        <div className="mt-14">
          <Endpoint method="GET" path="/v1/me" />
        </div>
        <p className="cw-p">Return the account&apos;s profile and weekly goals.</p>

        <h3 className="cw-h3">Example request</h3>
        <CodeBlock
          code={`curl ${BASE_URL}/v1/me \\
  -H "X-Api-Key: cw_your_key_here"`}
        />

        <h3 className="cw-h3">Example response</h3>
        <CodeBlock
          lang="json"
          code={`{
  "uid": "8f2c…",
  "goals": [
    { "category": "deep", "weeklyTargetHours": 20 },
    { "category": "rest", "weeklyTargetHours": 14 }
  ]
}`}
        />
      </Section>

      {/* Errors */}
      <Section id="errors" title="Errors">
        <p className="cw-p">
          Errors return a non-2xx status and a JSON body of the form{" "}
          <code className="cw-code">{`{ "error": "message" }`}</code>.
        </p>
        <ParamTable
          head={["Status", "Meaning", ""]}
          rows={[
            ["400", "Bad request", "Invalid from / to date, or from is not before to."],
            ["401", "Unauthorized", "Missing, malformed, or unknown API key."],
            ["500", "Server error", "Something went wrong on our side — retry."],
          ]}
        />
      </Section>

      {/* Agent skill */}
      <Section id="agents" title="Use it with an AI agent">
        <p className="cw-p">
          Cronwatch ships a ready-made <strong>agent skill</strong> — a single
          Markdown file describing the API in the format Claude Code and other
          coding agents understand. Drop it into your agent and it learns how to
          read your time on its own.
        </p>

        <div className="flex flex-wrap items-center gap-3 my-5">
          <a
            href={SKILL_URL}
            download="skill.md"
            className="inline-flex h-11 items-center gap-2 rounded-[10px] bg-ink px-5 text-[14px] font-semibold tracking-[-0.01em] text-white transition-all duration-150 hover:bg-black hover:shadow-[0_6px_18px_rgba(0,0,0,0.15)] active:translate-y-px"
          >
            Download skill.md
          </a>
          <a
            href={SKILL_URL}
            className="inline-flex h-11 items-center gap-2 rounded-[10px] border border-line bg-white px-5 text-[14px] font-semibold text-ink-muted transition-colors hover:text-ink hover:border-amber-soft font-mono text-[13px]"
          >
            View raw
          </a>
        </div>

        <h3 className="cw-h3">Install in Claude Code</h3>
        <p className="cw-p">
          Save the file as a skill, then add your key as an environment
          variable so it never lives in the prompt:
        </p>
        <CodeBlock
          code={`# Add the skill to your project (or ~/.claude/skills)
mkdir -p .claude/skills/cronwatch
curl -fsSL https://cronwatch.xyz/skill.md \\
  -o .claude/skills/cronwatch/SKILL.md

# Make your key available to the agent
export CRONWATCH_API_KEY="cw_your_key_here"`}
        />

        <h3 className="cw-h3">Or paste a system prompt</h3>
        <p className="cw-p">
          For a Claude project, an assistant, or any LLM with tool/HTTP access,
          paste this into the system prompt (swap in your key):
        </p>
        <CodeBlock code={AGENT_PROMPT} />
      </Section>

      {/* Footer nav */}
      <div className="mt-16 pt-8 border-t border-line flex flex-wrap gap-x-6 gap-y-2 text-[14px]">
        <Link href="/#api" className="text-amber-deep hover:text-ink transition-colors">
          ← Back to overview
        </Link>
        <Link href="/support" className="text-ink-muted hover:text-ink transition-colors">
          Questions? Support
        </Link>
      </div>
    </div>
  );
}

/* ---------- building blocks ---------- */

function Glance({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl border border-line bg-white px-4 py-3.5 shadow-tile-sm">
      <div className="font-mono text-[11px] uppercase tracking-[0.1em] text-caption mb-1.5">
        {label}
      </div>
      <div className="font-mono text-[14px] text-ink font-medium break-words">
        {value}
      </div>
    </div>
  );
}

function Section({
  id,
  title,
  children,
}: {
  id: string;
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section id={id} className="mt-16 scroll-mt-24">
      <h2 className="text-[26px] font-semibold tracking-[-0.02em] m-0 mb-5 pb-3 border-b border-line">
        {title}
      </h2>
      {children}
    </section>
  );
}

function Step({
  n,
  title,
  children,
}: {
  n: number;
  title: string;
  children: React.ReactNode;
}) {
  return (
    <li className="flex gap-4">
      <div className="w-7 h-7 rounded-full bg-amber flex-shrink-0 grid place-items-center text-white text-[13px] font-semibold mt-0.5">
        {n}
      </div>
      <div className="flex-1">
        <div className="text-[17px] font-semibold tracking-[-0.015em] mb-1.5">
          {title}
        </div>
        <div className="text-[15px] text-ink-muted leading-[1.65]">{children}</div>
      </div>
    </li>
  );
}

function Endpoint({ method, path }: { method: string; path: string }) {
  return (
    <div className="flex items-center gap-3 mb-3">
      <span className="text-[11px] font-semibold uppercase tracking-[0.08em] text-amber-deep bg-amber-faint px-2 py-1 rounded-md">
        {method}
      </span>
      <code className="font-mono text-[16px] text-ink font-semibold">{path}</code>
    </div>
  );
}

function ParamTable({
  rows,
  head = ["Field", "Type", "Description"],
}: {
  rows: [string, string, string][];
  head?: [string, string, string];
}) {
  return (
    <div className="overflow-x-auto rounded-xl border border-line my-4">
      <table className="w-full border-collapse text-[14px]">
        <thead>
          <tr className="bg-bg-cream/60">
            {head.map((h, i) => (
              <th
                key={i}
                className="text-left font-semibold text-caption text-[12px] uppercase tracking-[0.06em] px-4 py-2.5 border-b border-line"
              >
                {h}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map(([name, type, desc], i) => (
            <tr key={name} className={i > 0 ? "border-t border-line-soft" : ""}>
              <td className="px-4 py-3 align-top">
                <code className="font-mono text-[13px] text-ink">{name}</code>
              </td>
              <td className="px-4 py-3 align-top whitespace-nowrap">
                <span className="font-mono text-[13px] text-caption">{type}</span>
              </td>
              <td className="px-4 py-3 align-top text-ink-muted leading-[1.55]">
                {desc}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function CodeBlock({
  code,
  lang,
  className = "",
}: {
  code: string;
  lang?: string;
  className?: string;
}) {
  return (
    <div className={`relative group ${className}`}>
      <div className="absolute right-3 top-3 z-10">
        <CopyButton text={code} />
      </div>
      {lang && (
        <span className="absolute left-4 top-3 font-mono text-[11px] text-[#9A9A95] uppercase tracking-[0.08em]">
          {lang}
        </span>
      )}
      <pre
        className={`bg-ink text-[#FAFAF7] rounded-2xl p-5 ${
          lang ? "pt-9" : ""
        } overflow-x-auto text-[13px] leading-[1.65] font-mono shadow-tile-md`}
      >
        <code>{code}</code>
      </pre>
    </div>
  );
}
