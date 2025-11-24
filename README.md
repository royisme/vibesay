# Hex — Developer's Voice Input

> **专注为开发者打造的 macOS 语音输入工具。**
> 特别优化中英文混合输入场景，精准识别技术术语、函数名与代码片段。

**[开发路线图 (Roadmap)](docs/ROADMAP.md)** | **[架构与优化方案](docs/architecture_and_optimization_plan.md)**

Hex 是一个开源的 macOS 菜单栏应用，基于 **[TCA](https://github.com/pointfreeco/swift-composable-architecture)** 架构构建。
本项目（Fork 版）致力于解决开发者在语音输入时的核心痛点：**中英文夹杂识别率低、专业术语拼写错误**。

通过结合 **Whisper/Parakeet** 的强大听力与 **LLM (大语言模型)** 的理解能力，Hex 能“听懂”你的代码意图。

## 核心特性 (Features)

*   **⚡️ 极速转录**: 支持 [WhisperKit](https://github.com/argmaxinc/WhisperKit) (CoreML) 和 [FluidAudio/Parakeet](https://github.com/FluidInference/FluidAudio) 端侧模型。
*   **🧠 智能纠错 (Coming Soon)**: 利用 LLM (Ollama/OpenAI) 对识别结果进行后处理，自动修正 `kubernetes`, `async/await`, `useEffect` 等技术名词的拼写错误。
*   **🔌 开放模型生态 (Planned)**: 将支持直接从 Hugging Face 下载任意 CoreML 模型，不再受限于预置列表。
*   **⌨️ 开发者友好**: 专为 Xcode, VSCode, Cursor 等编辑器优化，支持自定义 "Coding Mode"。

## 快速开始 (Getting Started)

1.  **下载**: (请自行编译或等待发布)
2.  **权限**: 首次运行需授予麦克风和辅助功能权限（用于自动粘贴）。
3.  **使用**:
    *   **按住** 全局热键说话，松开即转录。
    *   **双击** 热键锁定录音，再次单击结束。

## 开发计划 (Roadmap)

我们需要你的帮助来共同打造这个工具！请查看 **[docs/ROADMAP.md](docs/ROADMAP.md)** 了解详细的迭代计划，包括：

*   **阶段一**: LLM 后处理流水线与 Prompt 优化。
*   **阶段二**: 自定义 Hugging Face 模型源。
*   **阶段三**: IDE 上下文感知 (RAG)。

## 构建与贡献 (Development)

本项目使用 Swift 开发，依赖 **Xcode 15+** 和 **macOS 14+**。

```bash
# 克隆仓库
git clone https://github.com/YourUsername/Hex.git
cd Hex

# 构建
xcodebuild -scheme Hex -configuration Release
```

欢迎提交 Issue 或 PR！详细架构分析请参阅 [架构文档](docs/architecture_and_optimization_plan.md)。

## License

This project is licensed under the MIT License.
Based on the original work by [Kit Langton](https://github.com/kitlangton/Hex).
