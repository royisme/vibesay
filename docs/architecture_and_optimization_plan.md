# Hex 架构分析与开发计划

本文档旨在分析 Hex 项目的当前架构，并针对“中英文混合输入优化”和“模型扩展性增强”提出具体的实施方案。

## 1. 架构概览 (Architecture Overview)

Hex 是一个基于 **TCA (The Composable Architecture)** 构建的 macOS 菜单栏应用。

### 核心模块
*   **Hex (App Target)**: 包含 UI 层、Features（TCA Reducers）和 Clients（依赖注入）。
*   **HexCore (Package)**: 包含核心业务逻辑、模型定义、工具类和通用的 Client 接口。

### 关键 Feature
*   **AppFeature**: 根节点，协调应用生命周期。
*   **TranscriptionFeature**: 处理录音、转录、后处理的核心流程。
*   **ModelDownloadFeature**: 管理模型的下载和状态。
*   **TextTransformationFeature**: 管理文本处理管道（包括 LLM 后处理）。

### 转录流程 (Transcription Flow)
1.  **录音**: `RecordingClient` 捕获音频。
2.  **转录**: `TranscriptionClient` 调用 CoreML 模型 (WhisperKit 或 Parakeet)。
3.  **后处理**: `TranscriptionFeature` 根据 `TextTransformationPipeline` 对文本进行处理（如大小写调整、标点修正、LLM 纠错）。
4.  **输出**: 自动粘贴到当前活动窗口或存入剪贴板。

---

## 2. 中英文混合输入优化方案 (Mixed Input Optimization)

针对开发者在中文语音输入中频繁夹杂英文技术名词（如函数名、类库、专业术语）的场景，单纯依靠 ASR（语音识别）模型往往难以达到完美效果（容易识别为同音中文字或错误的英文单词）。

**核心策略：利用 LLM 后处理 (Post-processing)**

Hex 现有的 `TextTransformationPipeline` 已经完美支持接入 LLM（如 Ollama, Claude, OpenAI 等）。我们可以利用这一点，配置专门的“开发者模式”。

### 2.1 方案设计
1.  **新增 "Coding" 模式**:
    *   在 `TextTransformations` 中创建一个新 Mode。
    *   **Trigger**: 配置 `Bundle ID` 绑定到常见 IDE (Xcode: `com.apple.dt.Xcode`, VSCode: `com.microsoft.VSCode`, Cursor 等)。
    *   **Pipeline**: 添加一个 `LLM Transformation` 节点。

2.  **Prompt 提示词工程**:
    *   利用 LLM 的上下文理解能力，修复 ASR 的拼写错误。
    *   **推荐 Prompt Template**:
        ```text
        你是一个资深的软件开发助手。用户正在使用语音输入编写技术文档或代码。
        输入文本是一段中文与英文技术术语混合的语音转录结果，其中英文术语可能因为发音问题被识别错误（可能是同音中文或拼写错误的单词）。
        请修正文本中的技术术语错误，保持原意不变。只输出修正后的文本，不要包含任何解释。

        上下文线索：Swift, Python, LLM, TCA, Git, Kubernetes.

        输入: {{input}}
        ```

3.  **低延迟建议**:
    *   为了保证输入体验，建议配合本地运行的小参数量 LLM（如 `Ollama` 运行 `qwen2.5-coder:7b` 或 `llama3.2:3b`）。这些模型对中英混杂和代码术语有很好的理解，且响应速度快。

---

## 3. 模型扩展方案 (Model Extension)

目前 `TranscriptionClient` 强绑定了 `argmaxinc/whisperkit-coreml` 仓库，限制了用户使用 Hugging Face 上其他优秀的 CoreML 转换模型。

### 3.1 核心痛点
*   **硬编码路径**: `TranscriptionClient.swift` 中模型存储路径硬编码为 `.../models/argmaxinc/whisperkit-coreml/`。
*   **列表限制**: `getAvailableModels` 仅从特定源获取列表。

### 3.2 改造计划

#### 3.2.1 扩展存储结构
修改文件存储逻辑，支持按 `Owner/Repo` 结构存储模型：
*   旧路径: `.../models/argmaxinc/whisperkit-coreml/model-name`
*   新路径: `.../models/{Owner}/{Repo}/model-name`

#### 3.2.2 支持任意 HF 仓库
修改 `downloadModel` 方法，支持解析形如 `User/Repo:ModelName` 的标识符。
*   如果用户输入 `zhuzilin/whisper-large-v3-coreml`，系统应能自动识别并从 HF 下载。

#### 3.2.3 UI 改进 (Advanced Mode)
在 Settings -> Model 页面增加“高级模式”或“自定义模型”入口：
*   **Add Model**: 允许用户输入 HF Repo ID。
*   **Auto-Update**: 后台定期检查 HF Commit Hash，提示用户更新。

---

## 4. 后续开发路线 (Next Steps)

请参考根目录下的 `docs/ROADMAP.md` 获取详细的分阶段实施计划。
