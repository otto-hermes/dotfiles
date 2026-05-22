# Hermes Prompt Budget Report

Generated: 2026-05-21T09:45:23

Read-only measurement. Counts are pre-user input: rendered system prompt parts plus active tool schemas.

## cli

Model: `nous/google/gemini-3-flash-preview`
Tokenizer: `tiktoken:cl100k_base`
Configured toolsets: 28
Loaded tool schemas: 33

### Component tokens

- system_stable_identity_guidance_skills: **5,470**
- context_files: **0**
- memory_user_timestamp: **923**
- tool_schemas: **11,953**
- total_pre_user_input: **18,346**
- estimated baseline input cost/request at $0.5/M input tokens: **$0.009173**

### Toolset schema tokens

- cronjob: 1,640
- delegation: 1,550
- terminal: 1,293
- browser: 1,224
- skills: 1,107
- file: 1,085
- session_search: 1,000
- code_execution: 660
- memory: 463
- messaging: 347
- web: 331
- todo: 288
- clarify: 279
- tts: 202
- vision: 188
- video: 170
- moa: 126

### Top tool schemas

- cronjob (cronjob): 1,640
- delegate_task (delegation): 1,550
- terminal (terminal): 1,021
- session_search (session_search): 1,000
- skill_manage (skills): 856
- execute_code (code_execution): 660
- memory (memory): 463
- search_files (file): 372
- patch (file): 354
- send_message (messaging): 347
- todo (todo): 288
- clarify (clarify): 279
- process (terminal): 272
- read_file (file): 202
- text_to_speech (tts): 202
- browser_navigate (browser): 198
- browser_vision (browser): 198
- skill_view (skills): 194
- browser_console (browser): 190
- vision_analyze (vision): 188

## telegram

Model: `nous/google/gemini-3-flash-preview`
Tokenizer: `tiktoken:cl100k_base`
Configured toolsets: 29
Loaded tool schemas: 33

### Component tokens

- system_stable_identity_guidance_skills: **5,554**
- context_files: **0**
- memory_user_timestamp: **923**
- tool_schemas: **11,953**
- total_pre_user_input: **18,430**
- estimated baseline input cost/request at $0.5/M input tokens: **$0.009215**

### Toolset schema tokens

- cronjob: 1,640
- delegation: 1,550
- terminal: 1,293
- browser: 1,224
- skills: 1,107
- file: 1,085
- session_search: 1,000
- code_execution: 660
- memory: 463
- messaging: 347
- web: 331
- todo: 288
- clarify: 279
- tts: 202
- vision: 188
- video: 170
- moa: 126

### Top tool schemas

- cronjob (cronjob): 1,640
- delegate_task (delegation): 1,550
- terminal (terminal): 1,021
- session_search (session_search): 1,000
- skill_manage (skills): 856
- execute_code (code_execution): 660
- memory (memory): 463
- search_files (file): 372
- patch (file): 354
- send_message (messaging): 347
- todo (todo): 288
- clarify (clarify): 279
- process (terminal): 272
- read_file (file): 202
- text_to_speech (tts): 202
- browser_navigate (browser): 198
- browser_vision (browser): 198
- skill_view (skills): 194
- browser_console (browser): 190
- vision_analyze (vision): 188

## cron

Model: `nous/google/gemini-3-flash-preview`
Tokenizer: `tiktoken:cl100k_base`
Configured toolsets: 29
Loaded tool schemas: 33

### Component tokens

- system_stable_identity_guidance_skills: **5,435**
- context_files: **0**
- memory_user_timestamp: **923**
- tool_schemas: **11,953**
- total_pre_user_input: **18,311**
- estimated baseline input cost/request at $0.5/M input tokens: **$0.009156**

### Toolset schema tokens

- cronjob: 1,640
- delegation: 1,550
- terminal: 1,293
- browser: 1,224
- skills: 1,107
- file: 1,085
- session_search: 1,000
- code_execution: 660
- memory: 463
- messaging: 347
- web: 331
- todo: 288
- clarify: 279
- tts: 202
- vision: 188
- video: 170
- moa: 126

### Top tool schemas

- cronjob (cronjob): 1,640
- delegate_task (delegation): 1,550
- terminal (terminal): 1,021
- session_search (session_search): 1,000
- skill_manage (skills): 856
- execute_code (code_execution): 660
- memory (memory): 463
- search_files (file): 372
- patch (file): 354
- send_message (messaging): 347
- todo (todo): 288
- clarify (clarify): 279
- process (terminal): 272
- read_file (file): 202
- text_to_speech (tts): 202
- browser_navigate (browser): 198
- browser_vision (browser): 198
- skill_view (skills): 194
- browser_console (browser): 190
- vision_analyze (vision): 188

## Cross-platform comparison

- telegram vs cli: +84 tokens (+0.5%)
- cron vs cli: -35 tokens (-0.2%)


## Pricing note

The cost estimate uses the public OpenRouter page for `google/gemini-3-flash-preview`, observed 2026-05-21: input `$0.50 / 1M` tokens, output `$3 / 1M` tokens. Hermes is currently configured for the Nous provider, so treat this as a pricing proxy unless/ until a Nous-specific metering page is available.
