# Which transcription APIs handle Swiss German mixed with Standard German and English, and at what price and limits?

Ticket: https://github.com/migilabs/Mispher/issues/4 · Researched 2026-10-24

> **How this was read.** The session's network policy blocked most vendor and paper sites. Read directly: OpenAI's GitHub-hosted spec, SDK and Cookbook, Google's pricing page, and an archived AWS docs table. Everything else comes from search-engine extracts of the cited pages, so it gets at most **medium** confidence. Prices and limits as of 2026-10-24.

## Answer

- **`gpt-transcribe` exists.** OpenAI added it on 2026-07-28 for completed files. It costs **0.0045 USD/min** and accepts `keywords` and a `languages` array. Its output is **JSON text only: no timestamps and no speakers.** OpenAI documents no Swiss German support. Confidence: high for existence and features, medium for price.
- **The concept's deprecation claim is right but incomplete.** On 2026-08-26 OpenAI announced that on **2027-02-26** it removes `whisper-1`, `gpt-4o-transcribe`, `gpt-4o-mini-transcribe` and `gpt-4o-transcribe-diarize`, plus the `/v1/audio/translations` endpoint. After that date OpenAI has no file model with timestamps or speaker labels. Confidence: medium-high.
- **Azure is the only big cloud that documents Swiss German dialect.** Its `de-CH` locale was announced in 2021 to recognise Swiss German dialect and write Standard German. AWS (`de-CH`, batch only) and Deepgram (Nova-3 `de-CH`, monolingual) list the locale but don't say it covers dialect. Google Chirp 3 and Chirp 2 list only `de-DE`. Confidence: medium.
- **No vendor publishes Swiss German accuracy figures,** including OpenAI. Speechmatics, Soniox and several Swiss services claim Swiss German only in marketing copy. Confidence: medium.
- **The research roughly supports the concept's "30–40 % WER".** Spontaneous Swiss German measured against Standard German references scores **25–40 % WER** with Whisper-class models. The content-word error rate is much lower (about 14 %), because much of the WER counts valid rewordings as errors. Confidence: medium.
- **Price is not the deciding factor.** At 20 h/month, every candidate costs between about 2 and 20 USD/month. Confidence: medium.

| Provider / model | Swiss German claim | USD/min (2026-10-24) | Keywords | Timestamps / speakers | EU / CH hosting |
|---|---|---|---|---|---|
| OpenAI `gpt-transcribe` | none; ISO-639-1 hints only | 0.0045 | `keywords` + `prompt` | no / no | EU (EEA+CH) only with ZDR/MAM approval |
| Azure Speech `de-CH` (fast/batch) | yes, dialect → Standard German (2021) | batch ≈ 0.003, real-time ≈ 0.0167 (secondary) | phrase list | yes / yes (2–35) | Switzerland North (batch, real-time) |
| Azure MAI-Transcribe-2 | not stated (60 languages) | ≈ 0.0017 (promo to 2026-12-31) | phrase list | yes / yes | Azure regions |
| Google Chirp 3 | no (`de-DE` only) | 0.016 (V2 standard) | ≤ 1,000 phrases | yes / yes (`de-DE`) | EU regions (preview) |
| AWS Transcribe `de-CH` | listed, batch only | 0.024 or 0.006 (conflicting) | custom vocabulary | yes / yes (≤ 30) | Frankfurt; Zurich unconfirmed |
| Deepgram Nova-3 `de-CH` | listed, monolingual | 0.0043 + 0.0013 keyterms | ≤ 100 keyterms | yes / yes | EU endpoint |
| Soniox | "handles Swiss German" (marketing) | ≈ 0.0017 | custom context (token-billed) | n/v | EU region |
| Speechmatics | Swiss German named as accent | ≈ 0.0038–0.0063 | ≤ 1,000 terms | yes / yes | EU processing |
| ElevenLabs Scribe v2 | none found | ≈ 0.0037 + keyterms | ≤ 100 keyterms | yes / yes (32) | EU residency on Enterprise only |
| AssemblyAI Universal-3.5 Pro | none; German with code-switching | ≈ 0.0035 | keyterms | yes / yes | EU endpoint |
| Gladia Solaria | none found | ≈ 0.0027–0.0045 (EUR) | custom vocabulary | yes / yes | EU-hosted |

n/v = not verified.

## Findings

**OpenAI.**
- **Model and fields.** OpenAI's API spec and SDK list `gpt-transcribe`. Its `keywords` and `languages` fields are "Supported by `gpt-transcribe`" ([openai-python `transcription_create_params.py`](https://github.com/openai/openai-python/blob/main/src/openai/types/audio/transcription_create_params.py); [OpenAPI spec](https://github.com/openai/openai-openapi)). The SDK changelog dates the addition to 2026-07-28 ([CHANGELOG](https://github.com/openai/openai-python/blob/main/CHANGELOG.md)). High.
- **Language hints.** `languages` takes ISO-639-1 codes only, and Swiss German (`gsw`) has none. The best hint is therefore `["de","en"]`. High.
- **Formats.** flac, mp3, mp4, mpeg, mpga, m4a, ogg, wav, webm (spec). High.
- **Output.** The migration Cookbook says the new model "returns JSON" and to keep `whisper-1` for timestamps and `gpt-4o-transcribe-diarize` for speaker labels. An invalid keyword rejects the whole request ([Cookbook](https://github.com/openai/openai-cookbook/blob/main/examples/migrating_from_whisper_to_gpt_transcribe.ipynb)). High.
- **Price.** 0.0045 USD/min ([model page](https://developers.openai.com/api/docs/models/gpt-transcribe)). Medium.
- **Size and duration.** The upload limit is 25 MB ([speech-to-text guide](https://developers.openai.com/api/docs/guides/speech-to-text)). Medium. A forum post shows `gpt-4o-transcribe` rejecting audio over 1,500 s; that is secondary, and no duration cap is published for `gpt-transcribe`.
- **Deprecations.** Announced 2026-08-26, removal 2027-02-26, replaced by `gpt-transcribe` or `gpt-live-transcribe` ([deprecations](https://developers.openai.com/api/docs/deprecations), [changelog](https://developers.openai.com/api/docs/changelog)). Medium-high: consistent across several extracts, but the page could not be opened.
- **Retention and residency.** Abuse-monitoring logs are kept for up to 30 days by default. `/v1/audio/transcriptions` is eligible for zero data retention (ZDR) after approval. Europe (EEA + Switzerland) processing requires ZDR or Modified Abuse Monitoring (MAM) and a new Project ([data controls](https://developers.openai.com/api/docs/guides/your-data)). Medium.
- **Accuracy.** OpenAI publishes no WER for `gpt-transcribe`. The only figure found is for `gpt-live-transcribe`: 19.7 % across 22 Common Voice languages ([update post](https://developers.openai.com/blog/updates-audio-models)). Low-medium.

**Azure.**
- **Locale and dialect.** `de-CH` is a speech-to-text locale with fast transcription ([language support](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/language-support)). The 2021 general-availability notice says it recognises Swiss German dialect ([Azure update](https://azure.microsoft.com/en-au/updates/release-of-swiss-german-dialect-speech-to-text/)). Phrase lists for `de-CH` arrived in February 2024 ([release notes](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/releasenotes)). Medium.
- **Fast transcription.** Supports diarization for 2–35 speakers on single-channel audio, a phrase list, and several locales with language identification ([fast transcription](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/fast-transcription-create)). Medium.
- **Swiss hosting.** Switzerland North offers real-time and batch transcription, but fast transcription is listed for Germany West Central ([regions](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/regions)). Medium.
- **MAI-Transcribe-2.** 0.10 USD/h until 2026-12-31, 60 languages, 300 MB / 2 h, WAV/MP3/FLAC ([Foundry blog](https://techcommunity.microsoft.com/blog/azure-ai-foundry-blog/mai-transcribe-2-highest-quality-transcription-at-the-fastest-speed-and-lowest-c/4550972), [model card](https://microsoft.ai/pdf/MAI-Transcribe-2-Model-Card.pdf)). Swiss German is not confirmed. Medium.
- **Prices.** The official page shows placeholders. The 1 USD/h real-time and 0.18 USD/h batch figures come from an aggregator (secondary). Low.

**Google.**
- **Pricing.** V2 standard recognition is 0.016 USD/min up to 500,000 min/month. "Dynamic batch" is 0.003 USD/min at lower urgency ([pricing](https://cloud.google.com/speech-to-text/pricing), read directly). High.
- **Languages.** The Chirp 3 and Chirp 2 tables list only `de-DE` ([Chirp 3](https://docs.cloud.google.com/speech-to-text/docs/models/chirp-3), [Chirp 2](https://docs.cloud.google.com/speech-to-text/docs/models/chirp-2)). Medium.
- **Chirp 3 features.** Phrase adaptation up to 1,000 phrases and diarization. Batch audio runs from about 1 min to 1 h, or 20 min with word timestamps. Medium.

**AWS.**
- **Language.** `de-CH` "German, Swiss" is batch only, without custom language models ([archived docs table](https://github.com/awsdocs/amazon-transcribe-developer-guide/blob/master/doc_source/supported-languages.md), ~2023). Medium.
- **Limits.** 2 GB per file. Duration is 4 h in the Medical docs and 8 h in the service card. Up to 30 speakers ([service card](https://docs.aws.amazon.com/ai/responsible-ai/transcribe-speech-recognition/overview.html)). Medium.
- **Price and Zurich.** Price conflicts between 0.024 USD/min (several blogs) and 0.006 USD/min (one October 2026 blog); both are secondary. Zurich availability is unconfirmed. Low.

**Deepgram.**
- **Language and price.** `de-CH` appears in the Nova-3 monolingual set; the multilingual set lists only `de` ([models](https://developers.deepgram.com/docs/models-languages-overview)). Price is 0.0043 USD/min, plus 0.0013 USD/min for keyterms ([pricing](https://deepgram.com/pricing)). Medium.
- **Limits.** 2 GB per file ([docs](https://developers.deepgram.com/docs/pre-recorded-audio)).
- **Retention.** Requests are retained for model improvement **by default** unless `mip_opt_out=true`. The EU endpoint is `api.eu.deepgram.com` ([your data](https://developers.deepgram.com/trust-security/your-data)). Medium.

**Others** (vendor marketing; medium-low). The table rows come from these pages: Soniox ([pricing](https://soniox.com/pricing), [German](https://soniox.com/speech-translation/german)), Speechmatics ([pricing](https://www.speechmatics.com/pricing), [German](https://www.speechmatics.com/speech-to-text/german)), ElevenLabs ([pricing](https://elevenlabs.io/pricing/api), [convert](https://elevenlabs.io/docs/api-reference/speech-to-text/convert); 3 GB / 10 h), AssemblyAI ([pricing](https://www.assemblyai.com/pricing), [region](https://www.assemblyai.com/docs/pre-recorded-audio/select-the-region)) and Gladia ([Solaria](https://www.gladia.io/solaria); self-serve trains on customer data by default). Swiss services claim dialect support and Swiss hosting, but their prices and accuracy are unverified: Suisse Speech, Suisse Line (Zurich), Swisscribe (OpenAI-compatible API), SwissTranscript (API announced for end of September 2026) and Spitch (enterprise) ([suisse-speech.ch](https://suisse-speech.ch/), [suisse-line.ch](https://suisse-line.ch/en/speech-api/), [swisscribe.ch](https://swisscribe.ch/en), [swisstranscript.ch](https://swisstranscript.ch/en/index.html)).

**Research on Swiss German error rates.** Papers were read via extracts; medium.
- **Dolev et al., VarDial 2024.** Whisper is "a viable ASR system for Swiss German, so long as the Standard German output is desired." The clinical-interview WER of about 0.33 comes from a secondary summary ([arXiv 2404.19310](https://arxiv.org/abs/2404.19310)).
- **SwissGPC v1.0, SwissText 2025.** About 5,000 h of spontaneous talk-show and podcast speech. Whisper large-v3 Standard German transcripts score WER **0.30 ± 0.26** on 100 samples ([arXiv 2509.19866](https://arxiv.org/abs/2509.19866)).
- **Akeret, 2026 preprint.** Reports an "honest" **25.6 % WER / 13.8 % cWER** and calls the published 17 % results inflated by contamination. It also observes English interpolations and hallucinations ([arXiv 2606.07608](https://arxiv.org/abs/2606.07608)).
- **SwissText 2020 shared task.** The winning system scored 40.3 % WER, as cited in [arXiv 2301.06790](https://arxiv.org/abs/2301.06790).
- **Read speech.** On read speech (STT4SG-350), an XLS-R baseline scores 14.0 % WER ([arXiv 2305.18855](https://arxiv.org/abs/2305.18855)).

## Gaps

- **Unopened primary pages.** The OpenAI deprecations, pricing and model pages, plus all Azure, AWS, Deepgram and other docs, were read only via search extracts. Re-check them with network access to those hosts.
- **Duration cap.** No published duration cap for `gpt-transcribe`. Test one 60-minute file.
- **Azure details.** Not confirmed whether Azure `de-CH` currently writes Standard German, and Azure's fast-transcription price is unknown.
- **Locale meaning.** Not confirmed whether the AWS and Deepgram `de-CH` locales cover dialect or only Swiss Standard German.
- **Accuracy.** No independent accuracy numbers exist for any 2026 commercial API on Swiss German. Only ticket #12's test with real Recordings can settle quality, especially on code-switching into English.
- **Deprecations elsewhere.** Only OpenAI's deprecation list was checked; other vendors' deprecation pages were not.

## Implications for Mispher

- **#12 (pipeline prototype), candidates to test.** `gpt-transcribe` with `languages: ["de","en"]` and the Keywords; Azure `de-CH` fast transcription with a phrase list; and one Swiss-German-focused provider (Soniox, or a Swiss service such as Swisscribe). Deepgram `de-CH` would show whether a monolingual model breaks on English passages. The `gpt-4o-*` and `whisper-1` models are not worth testing: they go away on 2027-02-26.
- **#14 (Transcript format).** With `gpt-transcribe` the Transcript has no timestamps and no speakers. Choosing it means a Transcript of plain text per Segment.
- **#17 (Stop to Protocol).** At about 14 MB/h, 25 MB covers about 1.7 h by size. The duration cap is unknown, so chunking may be needed. Google dynamic batch and AWS batch latencies were not checked against the 5-minute target.
- **#13 (provider choice).** Retention defaults differ: OpenAI keeps abuse logs for 30 days, Deepgram retains requests unless opted out, Gladia trains by default. Swiss or EU hosting is a criterion to weigh, not yet a requirement on the map.

## Sources

- https://github.com/openai/openai-python/blob/main/src/openai/types/audio/transcription_create_params.py
- https://github.com/openai/openai-python/blob/main/CHANGELOG.md
- https://github.com/openai/openai-openapi
- https://github.com/openai/openai-cookbook/blob/main/examples/migrating_from_whisper_to_gpt_transcribe.ipynb
- https://developers.openai.com/api/docs/models/gpt-transcribe
- https://developers.openai.com/api/docs/deprecations
- https://developers.openai.com/api/docs/changelog
- https://developers.openai.com/api/docs/guides/speech-to-text
- https://developers.openai.com/api/docs/guides/your-data
- https://developers.openai.com/blog/updates-audio-models
- https://learn.microsoft.com/en-us/azure/ai-services/speech-service/language-support
- https://learn.microsoft.com/en-us/azure/ai-services/speech-service/fast-transcription-create
- https://learn.microsoft.com/en-us/azure/ai-services/speech-service/regions
- https://learn.microsoft.com/en-us/azure/ai-services/speech-service/releasenotes
- https://azure.microsoft.com/en-au/updates/release-of-swiss-german-dialect-speech-to-text/
- https://techcommunity.microsoft.com/blog/azure-ai-foundry-blog/mai-transcribe-2-highest-quality-transcription-at-the-fastest-speed-and-lowest-c/4550972
- https://microsoft.ai/pdf/MAI-Transcribe-2-Model-Card.pdf
- https://cloud.google.com/speech-to-text/pricing
- https://docs.cloud.google.com/speech-to-text/docs/models/chirp-3
- https://docs.cloud.google.com/speech-to-text/docs/models/chirp-2
- https://github.com/awsdocs/amazon-transcribe-developer-guide/blob/master/doc_source/supported-languages.md
- https://docs.aws.amazon.com/ai/responsible-ai/transcribe-speech-recognition/overview.html
- https://developers.deepgram.com/docs/models-languages-overview
- https://developers.deepgram.com/docs/pre-recorded-audio
- https://developers.deepgram.com/trust-security/your-data
- https://deepgram.com/pricing
- https://soniox.com/pricing
- https://soniox.com/speech-translation/german
- https://www.speechmatics.com/pricing
- https://www.speechmatics.com/speech-to-text/german
- https://elevenlabs.io/pricing/api
- https://elevenlabs.io/docs/api-reference/speech-to-text/convert
- https://www.assemblyai.com/pricing
- https://www.assemblyai.com/docs/pre-recorded-audio/select-the-region
- https://www.gladia.io/solaria
- https://suisse-speech.ch/ · https://suisse-line.ch/en/speech-api/ · https://swisscribe.ch/en · https://swisstranscript.ch/en/index.html
- https://arxiv.org/abs/2404.19310
- https://arxiv.org/abs/2509.19866
- https://arxiv.org/abs/2606.07608
- https://arxiv.org/abs/2301.06790
- https://arxiv.org/abs/2305.18855
- Secondary: https://community.openai.com/t/gpt4-0-transcribe-max-1500-seconds/1306684 (forum, 1,500 s cap for gpt-4o-transcribe); Azure and AWS price aggregators (developersdigest.tech, brasstranscripts.com)
