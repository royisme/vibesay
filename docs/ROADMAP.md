# Hex 开发路线图 (Roadmap)

> **产品愿景**: 打造最懂中文开发者的 macOS 语音输入工具。不仅是“转录”，更是“理解”开发者的意图，完美处理中英文混合的技术术语，无缝融入编码工作流。

## 阶段一：开发者体验核心优化 (Core Developer Experience)
*目标：解决中英文混合输入的准确性问题，确立“AI 后处理”的核心优势。*

- [ ] **LLM 后处理流水线增强**
  - [ ] 预置 "Coding Mode" 模板：针对 Xcode/VSCode/Cursor 等 IDE 自动激活。
  - [ ] 优化 Prompt 模板：内置针对 Swift/Python/Rust 等语言的专用纠错 Prompt。
  - [ ] 支持更多 LLM Provider：确保对 Ollama (本地) 和 OpenAI Compatible API 的完美支持。
- [ ] **文档与最佳实践**
  - [ ] 输出《开发者语音输入最佳实践指南》，指导用户配置本地 LLM 以获得零延迟体验。

## 阶段二：模型生态开放 (Open Model Ecosystem)
*目标：打破单一模型源限制，让用户能第一时间用上 Hugging Face 发布的最新 CoreML 模型。*

- [ ] **解除硬编码限制**
  - [ ] 重构 `TranscriptionClient`，支持任意 Hugging Face `User/Repo` 结构。
  - [ ] 兼容非 `whisperkit` 官方转换的模型结构。
- [ ] **高级模型管理 UI**
  - [ ] 新增“自定义模型”添加入口 (Input Repo ID)。
  - [ ] 模型版本管理：展示本地版本与远程 Commit Hash，支持增量更新。
- [ ] **自动化更新**
  - [ ] 后台定期检测已下载模型的更新，并推送通知。

## 阶段三：上下文感知与 RAG (Context Awareness)
*目标：让语音输入“看见”你的代码，实现真正的智能补全。*

- [ ] **IDE 上下文注入**
  - [ ] 开发 VSCode/Xcode 扩展或利用 Accessibility API，获取当前编辑器中的光标位置代码片段。
  - [ ] 将当前文件名、选中代码作为 Context 注入到 LLM Prompt 中，大幅提升变量名识别率。
- [ ] **项目级 RAG**
  - [ ] 索引当前项目的符号表（Symbol Table），确保语音输入的函数名与项目定义完全一致。

## 阶段四：Agent 能力探索 (Agentic Capabilities)
*目标：从“输入工具”进化为“语音编码助手”。*

- [ ] **语音重构指令**
  - [ ] 识别如“把这个函数重构为异步写法”的指令，而不仅仅是转录文字。
- [ ] **多模态交互**
  - [ ] 结合屏幕截图上下文进行语音问答。

---

*Hex 正在由一个通用的语音工具，进化为开发者的第二大脑入口。*
