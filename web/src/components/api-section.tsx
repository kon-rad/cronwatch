export function ApiSection() {
  return (
    <section id="api" className="py-20 md:py-[120px] border-t border-line">
      <div className="mx-auto w-[min(1200px,100%-48px)]">
        {/* Header */}
        <div className="reveal max-w-[720px] mb-16">
          <div className="text-[12px] font-semibold uppercase tracking-[0.12em] text-amber-deep mb-4">
            Developer API
          </div>
          <h2 className="text-[clamp(34px,4.4vw,52px)] font-semibold tracking-[-0.025em] leading-[1.05] m-0 mb-4">
            Give your agent access to your time.
          </h2>
          <p className="text-[18px] text-ink-muted m-0 max-w-[580px] leading-[1.55]">
            Create an API key in the app and hand it to any agent or script. It gets read-only access to your entries — nothing more.
          </p>
        </div>

        <div className="reveal-stagger grid gap-8 lg:grid-cols-2">
          {/* Left: how it works */}
          <div className="space-y-8">
            <Step n={1} title="Create a key in the app">
              Open Cronwatch → Profile → API Keys → tap the + button. Name it
              (e.g. &ldquo;My Claude Agent&rdquo;), tap Create. The full key is shown once — copy it somewhere safe.
            </Step>
            <Step n={2} title="Pass it to your agent">
              Add the key as context in your agent&apos;s system prompt, a{" "}
              <code className="font-mono text-[13px] bg-line-soft px-1.5 py-0.5 rounded">.env</code>{" "}
              file, or a secrets manager. The agent sends it as an HTTP header on every request.
            </Step>
            <Step n={3} title="Query your data">
              The agent calls{" "}
              <code className="font-mono text-[13px] bg-line-soft px-1.5 py-0.5 rounded">GET /v1/entries</code>{" "}
              with a date range. Cronwatch returns your structured time blocks — category, note, start,
              end — ready to summarise, export, or sync.
            </Step>
          </div>

          {/* Right: endpoint reference */}
          <div className="space-y-6">
            <EndpointCard
              method="GET"
              path="/v1/entries"
              description="List entries in a time window."
              params={[
                { name: "from", type: "ISO 8601", required: false, desc: "Window start. Default: 7 days ago." },
                { name: "to", type: "ISO 8601", required: false, desc: "Window end. Default: now." },
                { name: "limit", type: "integer", required: false, desc: "Max results (1–500). Default: 200." },
              ]}
              example={`curl https://api.cronwatch.xyz/v1/entries \\
  -H "X-Api-Key: cw_your_key_here" \\
  -G \\
  --data-urlencode "from=2025-01-01T00:00:00Z" \\
  --data-urlencode "to=2025-01-31T23:59:59Z"`}
            />

            <EndpointCard
              method="GET"
              path="/v1/me"
              description="Your profile and weekly goals."
              params={[]}
              example={`curl https://api.cronwatch.xyz/v1/me \\
  -H "X-Api-Key: cw_your_key_here"`}
            />
          </div>
        </div>

        {/* Response example */}
        <div className="reveal mt-12">
          <div className="text-[12px] font-semibold uppercase tracking-[0.1em] text-caption mb-4">
            Example response — /v1/entries
          </div>
          <pre className="bg-ink text-[#FAFAF7] rounded-2xl p-6 overflow-x-auto text-[13px] leading-[1.65] font-mono shadow-tile-lg">
            <code>{`{
  "entries": [
    {
      "id": "c_1737014400000_a1b2c3",
      "captureId": "c_1737014400000_a1b2c3",
      "category": "work",
      "note": "API architecture review",
      "startTime": "2025-01-16T09:00:00.000Z",
      "endTime":   "2025-01-16T10:30:00.000Z",
      "source": "voice",
      "transcript": "Spent ninety minutes on the API architecture…",
      "createdAt": "2025-01-16T10:31:22.000Z"
    }
  ],
  "count": 1
}`}</code>
          </pre>
        </div>

        {/* Agent prompt tip */}
        <div className="reveal mt-10 p-7 bg-amber-faint border border-amber-soft rounded-2xl">
          <div className="text-[12px] font-semibold uppercase tracking-[0.1em] text-amber-deep mb-3">
            Tip — giving a key to Claude
          </div>
          <p className="text-[15px] text-ink-muted leading-[1.6] m-0 mb-4">
            Paste this into a Claude project&apos;s system prompt (replacing the key):
          </p>
          <pre className="bg-white border border-line rounded-xl p-5 text-[13px] font-mono leading-[1.65] text-ink overflow-x-auto whitespace-pre-wrap">
            <code>{`You have access to the user's Cronwatch time-tracking data.
Base URL: https://api.cronwatch.xyz
Authentication: send header X-Api-Key: cw_your_key_here

Endpoints:
  GET /v1/me                           — goals & profile
  GET /v1/entries?from=ISO&to=ISO      — time entries in range

When the user asks about their time use, habits, or schedule,
call the relevant endpoint and reason over the results.`}</code>
          </pre>
        </div>

        {/* Docs + skill links */}
        <div className="reveal mt-8 flex flex-wrap items-center gap-3">
          <a
            href="/docs"
            className="inline-flex h-11 items-center gap-2 rounded-[10px] bg-ink px-5 text-[14px] font-semibold tracking-[-0.01em] text-white transition-all duration-150 hover:bg-black hover:shadow-[0_6px_18px_rgba(0,0,0,0.15)] active:translate-y-px"
          >
            Read the full API docs →
          </a>
          <a
            href="/skill.md"
            download="skill.md"
            className="inline-flex h-11 items-center gap-2 rounded-[10px] border border-line bg-white px-5 text-[14px] font-semibold text-ink-muted transition-colors hover:text-ink hover:border-amber-soft"
          >
            <span className="font-mono text-[13px]">skill.md</span>
            <span className="text-caption">for agents</span>
          </a>
        </div>
      </div>
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
    <div className="flex gap-5">
      <div className="w-8 h-8 rounded-full bg-amber flex-shrink-0 grid place-items-center text-white text-[13px] font-semibold mt-0.5">
        {n}
      </div>
      <div>
        <div className="text-[17px] font-semibold tracking-[-0.015em] mb-1">{title}</div>
        <p className="text-[15px] text-ink-muted leading-[1.6] m-0">{children}</p>
      </div>
    </div>
  );
}

function EndpointCard({
  method,
  path,
  description,
  params,
  example,
}: {
  method: "GET" | "POST";
  path: string;
  description: string;
  params: { name: string; type: string; required: boolean; desc: string }[];
  example: string;
}) {
  return (
    <div className="border border-line rounded-2xl overflow-hidden bg-white shadow-tile-sm">
      <div className="flex items-center gap-3 px-5 py-4 border-b border-line">
        <span className="text-[11px] font-semibold uppercase tracking-[0.08em] text-amber-deep bg-amber-faint px-2 py-0.5 rounded-md">
          {method}
        </span>
        <code className="font-mono text-[14px] text-ink font-semibold">{path}</code>
      </div>
      <div className="px-5 py-4">
        <p className="text-[14px] text-ink-muted m-0 mb-4">{description}</p>

        {params.length > 0 && (
          <div className="space-y-2 mb-4">
            {params.map((p) => (
              <div key={p.name} className="flex items-start gap-3 text-[13px]">
                <code className="font-mono text-ink bg-line-soft px-1.5 py-0.5 rounded flex-shrink-0">
                  {p.name}
                </code>
                <span className="text-caption flex-shrink-0">{p.type}</span>
                <span className="text-ink-muted leading-[1.5]">{p.desc}</span>
              </div>
            ))}
          </div>
        )}

        <pre className="bg-bg rounded-xl p-4 text-[12px] font-mono leading-[1.7] text-ink-muted overflow-x-auto border border-line-soft">
          <code>{example}</code>
        </pre>
      </div>
    </div>
  );
}
