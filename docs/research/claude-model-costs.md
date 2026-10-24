# What do the Protocol-writing Claude models cost, and can they return schema-checked output?
Ticket: https://github.com/migilabs/Mispher/issues/9 · Researched 2026-10-24

## Answer

- **The concept's prices are correct.** On Anthropic's own pages (read 2026-10-24), `claude-haiku-5-5` costs 0.10 / 0.50 USD and `claude-sonnet-5-5` costs 2 / 10 USD per million input / output tokens. Haiku's price applies only to prompts of up to 100,000 tokens; above that it is 0.50 / 2.50. **Confidence: high.**
- **Both models support schema-constrained JSON output (GA)** through `output_config: {format: {type: "json_schema", schema: …}}`, with no beta header. In three cases the output can still miss the schema: a refusal, a cut-off at `max_tokens`, or enum values with different capitalization. Validating on the client is still needed. **High.**
- **Batch API: 50 % off, but no turnaround guarantee.** Most batches finish within 1 hour, and a batch can take up to 24 hours before it expires. That cannot promise "Protocol within 5 minutes". It fits only non-urgent reprocessing. **High.**
- **Prompt caching barely matters for Mispher.** The minimum cacheable prefix is 512 tokens on both models, and the cache lives 5 minutes (1.25× write) or 1 hour (2× write). Protocol calls for different Recordings will rarely fall within 5 minutes of each other, so most calls would pay for a cache write and never read it. The whole Template input costs cents per month anyway. **High on the figures, medium on the usage pattern.**
- **Context and output limits are not a constraint.** Both models take 1M tokens of context and return up to 128K output tokens. A 60-min Transcript (~15–20K tokens) uses about 2 % of the window. **High.**
- **Both pipelines fit the < 10 USD target at 20 Recording hours**, using the concept's token estimates and its transcription price. Thinking tokens are not measured yet. **Medium.**

| per month, 20 h | Claude | Transcription | Total | Headroom |
|---|---|---|---|---|
| (a) Haiku cleanup + Sonnet Protocol | 1.54 USD | 5.40 USD | **6.94 USD** | 3.06 USD |
| (b) one Sonnet call | 1.30 USD | 5.40 USD | **6.70 USD** | 3.30 USD |

## Findings

### Prices and model IDs (as read 2026-10-24)

| | Haiku 5.5 (≤ 100K prompt) | Haiku 5.5 (> 100K) | Sonnet 5.5 |
|---|---|---|---|
| Model ID | `claude-haiku-5-5` | | `claude-sonnet-5-5` |
| Input / output per MTok | 0.10 / 0.50 | 0.50 / 2.50 | 2 / 10 |
| 5-min / 1-h cache write | 0.125 / 0.20 | 0.625 / 1 | 2.50 / 4 |
| Cache read | 0.01 | 0.05 | 0.10 |
| Batch input / output | 0.05 / 0.25 | 0.25 / 1.25 | 1 / 5 |

Sources: [pricing](https://platform.claude.com/docs/en/about-claude/pricing), the [Haiku 5.5](https://platform.claude.com/docs/en/models/haiku-5-5/overview) and [Sonnet 5.5](https://platform.claude.com/docs/en/models/sonnet-5-5/overview) model pages, and [claude.com/pricing](https://claude.com/pricing). All of them agree.

- Haiku's price depends on prompt length. The count includes cache reads and writes, and each request is priced on its own ([pricing: long context](https://platform.claude.com/docs/en/about-claude/pricing#long-context-pricing)).
- Sonnet 5.5 cache reads dropped from 0.20 to 0.10 USD on 2026-10-07 ([Haiku 5.5 announcement](https://www.anthropic.com/claude-haiku-5-5)). The `claude-api` skill (cached 2026-10-06) still lists 0.20. The pricing page wins.
- Model IDs are pinned snapshots with no date suffix ([models overview](https://platform.claude.com/docs/en/about-claude/models/overview)). Retirement not before 2027-10-07 (Haiku 5.5) and 2027-09-28 (Sonnet 5.5).
- **Thinking is billed as output.** Both models run adaptive thinking by default. Thinking tokens are "billed as output tokens, even when the thinking text isn't returned" ([thinking](https://platform.claude.com/docs/en/build-with-claude/thinking)). Default effort is `medium` on Haiku 5.5 and `high` on Sonnet 5.5 ([effort](https://platform.claude.com/docs/en/build-with-claude/effort)). Haiku accepts `thinking: {type: "disabled"}` at effort `high` or below. Sonnet 5.5 rejects `disabled` with a 400 error. Its lowest setting is `{type: "between_tools"}`, which turns off up-front thinking ([thinking: turning thinking off](https://platform.claude.com/docs/en/build-with-claude/thinking)).

### Structured output

- Both models are on the `supportedModels` list. The feature is GA on the Claude API ([structured outputs](https://platform.claude.com/docs/en/build-with-claude/structured-outputs)).
- To request it, put a JSON schema in `output_config.format` with `type: "json_schema"`. The JSON comes back in the text block. The old `output_format` parameter is deprecated and needs the `structured-outputs-2025-11-13` beta header. The alternative is `strict: true` on a tool definition.
- Schema limits:
  - every object needs `additionalProperties: false`
  - no `minimum`/`maximum` and no `minLength`/`maxLength`
  - `minItems` only 0 or 1
  - no recursive schemas
  - at most 24 optional parameters and 16 union-typed parameters per request

  The SDKs rewrite unsupported constraints, but there is no Swift SDK, so a raw HTTPS client must send a schema that already fits these limits.
- When output can miss the schema:
  - `stop_reason: "refusal"` (still billed)
  - `"max_tokens"`
  - enum values that differ only in capitalization

  A new schema's first request is slower (grammar compile, then cached 24 hours). An injected system prompt adds input tokens. Not compatible with citations or prefill.

### Message Batches API

- All usage costs 50 % of standard prices ([batch processing](https://platform.claude.com/docs/en/build-with-claude/batch-processing)).
- "Most batches completing within 1 hour"; unfinished requests expire after 24 hours, unbilled. Results stay available for 29 days.
- Batches support structured outputs. They do not support `stream` or server-side `fallbacks`.
- Conclusion: batch cannot meet a 5-minute target. It suits regenerating Protocols from the stored audio or Transcripts.

### Prompt caching for a fixed Template

- Minimum cacheable prompt: 512 tokens for both models. A shorter prefix is processed without caching, and the API returns no error ([prompt caching: limitations](https://platform.claude.com/docs/en/build-with-claude/prompt-caching#cache-limitations)).
- TTL is 5 minutes by default and is refreshed on every hit. A 1-hour TTL costs 2× on writes. Lifetime counts from the start of the request.
- Cache reads cost 0.1× of input on Haiku 5.5 and 0.05× on Sonnet 5.5.
- Worked example, assuming a 2,000-token Template on Sonnet (the real size is unknown):
  - without caching: 2,000 × 2 / 1M = 0.004 USD per call
  - 5-min write: 0.005 USD; read: 0.0002 USD
  - at 20 calls a month the whole Template costs 0.08 USD

  Caching only pays off when a call is repeated within the TTL, for example a retry or a regenerated Protocol.

### Context window and output

- Both models: 1M-token context and up to 128K output tokens per request (300K on Batch with a beta header) ([context windows](https://platform.claude.com/docs/en/build-with-claude/context-windows)).
- On the current tokenizer, 1M tokens ≈ 555K words ([models overview](https://platform.claude.com/docs/en/about-claude/models/overview)). That is ~1.8 tokens per word, so 8,500 words ≈ 15,300 tokens. The concept's 20,000 tokens per hour leaves margin for German compound words (not verified).
- Haiku's 20K-token cleanup output fits easily. Anthropic advises streaming (or Batch) for requests with a large `max_tokens`, because networks can drop idle connections ([errors: long requests](https://platform.claude.com/docs/en/api/errors#long-requests)).

### Monthly cost at 20 Recording hours (standard prices, per hour)

Concept token figures, 1 USD/MTok = 0.000001 USD per token:

- **Haiku cleanup:** 20,000 × 0.10 / 1M = 0.002 USD; 20,000 × 0.50 / 1M = 0.010 USD. Total **0.012 USD/h**.
- **Sonnet Protocol:** 20,000 × 2 / 1M = 0.040 USD; 2,500 × 10 / 1M = 0.025 USD. Total **0.065 USD/h**.
- **(a)** (0.012 + 0.065) × 20 = **1.54 USD**.
- **(b)** 0.065 × 20 = **1.30 USD**.
- **Transcription** (concept figure, not verified): 0.0045 × 60 × 20 = **5.40 USD**.
- **Totals:** (a) 6.94 USD, (b) 6.70 USD.
- **On Batch:** (a) 0.77 USD and (b) 0.65 USD for Claude.

**Sensitivity:**

- Sonnet thinking: every 1,000 thinking tokens per hour add 0.20 USD a month. The budget breaks only at about 15,300 extra Sonnet output tokens per hour in (a), or 16,500 in (b), roughly 6× the Protocol itself.
- Larger Transcripts: at 30K tokens per hour, (a) rises to 2.06 USD.
- Transcription is 78–81 % of the total.

## Gaps

- **Real token counts.** No real German or Swiss German Transcript was counted. To fix: run the free [`count_tokens`](https://platform.claude.com/docs/en/build-with-claude/token-counting) endpoint on the test Recordings (#10) on Michele's Mac.
- **Thinking and output size.** How many thinking tokens Haiku (`medium`) and Sonnet (`high`) spend on this task is unmeasured. To fix: log `usage.output_tokens` per call in #12.
- **Latency.** Anthropic publishes only relative latency (Haiku "Fastest", Sonnet "Fast"), not tokens per second. Whether a 20K-token Haiku output plus a Sonnet call fits in 5 minutes needs a timed run.
- **Transcription price.** OpenAI's pricing pages were blocked from this session (proxy 403), so 0.0045 USD/min is the concept's figure. #4 owns it.
- **Template size and schema overhead.** The token cost of the injected structured-output system prompt is not published. Both can be measured with `count_tokens`.

## Implications for Mispher

- **#13 (pipeline choice):** cost does not decide between (a) and (b). They differ by 0.24 USD a month. The choice depends on quality (#12) and latency: (a) adds a serial step that writes ~20K output tokens.
- **#4 (transcription provider):** transcription is the cost driver. Two-track Teams (P5, but inside the CLAUDE.md budget) could double transcription minutes for those Recordings; as an upper bound, 20 two-track hours would put transcription alone at 10.80 USD.
- **#17 (Stop to Protocol, failures and retries):** only synchronous calls can meet the 5-minute target, and long outputs call for streaming. Batch fits regeneration only. A retry within 5 minutes is the one case where a cached Template helps.
- **Schema rule in CLAUDE.md:** structured output covers the "validated against a JSON schema" rule on the API side. The app still has to handle refusal and `max_tokens` responses, and compare enum values without regard to case.
- **"Not yet specified": cost logging.** Logging `usage` (input, output, cache) per call would give the real numbers for the two-week check.

## Sources

- https://platform.claude.com/docs/en/about-claude/pricing
- https://claude.com/pricing
- https://platform.claude.com/docs/en/about-claude/models/overview
- https://platform.claude.com/docs/en/models/haiku-5-5/overview
- https://platform.claude.com/docs/en/models/sonnet-5-5/overview
- https://www.anthropic.com/claude-haiku-5-5
- https://www.anthropic.com/claude-sonnet-5-5
- https://platform.claude.com/docs/en/build-with-claude/structured-outputs
- https://platform.claude.com/docs/en/build-with-claude/batch-processing
- https://platform.claude.com/docs/en/build-with-claude/prompt-caching
- https://platform.claude.com/docs/en/build-with-claude/context-windows
- https://platform.claude.com/docs/en/build-with-claude/thinking
- https://platform.claude.com/docs/en/build-with-claude/effort
- https://platform.claude.com/docs/en/build-with-claude/token-counting
- https://platform.claude.com/docs/en/api/errors#long-requests
