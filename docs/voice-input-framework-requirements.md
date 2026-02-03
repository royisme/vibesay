# Voice Input Framework Requirements
- Date: 2026-02-03
- Owner: royzhu

## 1. Background
We need a macOS voice input solution that works across apps, supports modern ASR models (beyond Whisper), and remains maintainable. The current repo (Hex) is a strong base for a global hotkey dictation workflow, but we must validate build stability first, then isolate and understand differences from upstream.

## 2. Goals & Non-Goals
Goals:
- G1: Establish a clean, compilable upstream baseline on `main`.
- G2: Keep local work isolated on a dedicated branch and rebase cleanly later.
- G3: Identify a sustainable path to integrate new ASR models (SenseVoice/FunASR) without breaking the hotkey dictation UX.
- G4: Ensure the app can run as a global voice input tool across macOS apps.

Non-Goals:
- NG1: Rewriting the app as a system IME (InputMethodKit) in this phase.
- NG2: Implementing a full model marketplace or UI redesign now.

## 3. Requirements
| ID | Description | Priority | Acceptance Test |
|----|-------------|----------|-----------------|
| R1 | `main` must build successfully on macOS 14+ with Xcode 15+ | Must | Running `xcodebuild -scheme Hex -configuration Release` succeeds |
| R2 | Local changes must live on a dedicated branch | Must | `git branch --show-current` is `codex/vibesay-work` for local work |
| R3 | Rebase local work onto updated `main` after baseline build | Must | `git rebase main` completes without conflicts or with documented resolutions |
| R4 | Document delta between local work and upstream | Must | A diff summary is recorded in docs |
| R5 | Define an integration approach for non-Whisper ASR models | Should | A design note exists for SenseVoice/FunASR integration points |

## 4. Architecture / Design
- Baseline: Hotkey-driven dictation app with on-device transcription.
- Integration path: Add ASR backends through a model abstraction layer in HexCore, keeping front-end UX stable.
- Model strategy: Support WhisperKit/Parakeet now; evaluate SenseVoice/FunASR as additional backends via a shared interface.

## 5. Test Plan
- Build validation: `xcodebuild -scheme Hex -configuration Release`.
- Smoke run: Launch the app locally and verify hotkey → transcription → paste workflow.
- Model smoke: At least one Whisper/Parakeet model loads and transcribes a short clip.

## 6. Open Questions / TODO
- [ ] Decide integration method for SenseVoice/FunASR (native CoreML vs external service).
- [ ] Decide how to surface model selection to users (settings UI vs config file).
- [ ] Confirm if any entitlement changes are required for new models.

## 7. AI Correction (Optional)
AI Correction should be configurable and optional. When enabled, ASR output is post-processed by a user-selected AI prompt and then auto-typed.

### Configuration
- `enabled`: Bool
- `endpoint`: String (API base URL)
- `apiKey`: String (securely stored)
- `model`: String
- `prompt`: String (active prompt)
- `prompts`: [Prompt] (prompt library; create/update/delete)
- `timeoutMs`: Int (optional)
- `temperature`: Float (optional)
- `maxTokens`: Int (optional)
- `fallbackToRaw`: Bool (if AI fails, paste original ASR text)

### Flow
1. Dictate → ASR transcription
2. If `enabled`, call AI endpoint with selected prompt
3. Auto-type AI-enhanced result (or raw fallback)

## 8. Suggested Feature Roadmap
- MVP Dictation Loop: hotkey → record → ASR → paste
- Smart Post-Processing v1: remove filler words, repetitions, self-corrections
- Structured Formatting: convert dictated bullet points into lists
- Multi-Model Support: SenseVoice / FunASR / WhisperKit side-by-side
