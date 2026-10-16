# Validation

Run `./tests/verify.ps1` in PowerShell to exercise command generation and binding lifetime without contacting OpenAI, changing a user profile or executing generated commands. The suite replaces the HTTP and PSReadLine boundaries inside an isolated module session and restores the original process API-key value on exit.

The contracts cover complete text, fenced output, incomplete/failed responses, absent response fields, empty output, refusal output, missing credentials, binding replacement and repeated disable. The source is parsed and the same suite runs on Windows PowerShell 5.1 and PowerShell 7 in CI. A successful fixture proves client handling; live model availability and interactive desktop behaviour remain distinct evidence.

A push to `main` publishes a new manifest version only after both host suites pass. Publication archives that exact source revision, stages a draft, compares its complete remote asset set and bytes, then verifies the public assets and tag. Existing public versions remain immutable.
