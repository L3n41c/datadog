# AGENTS.md

Instructions for AI coding agents working on this repository. This file is the single source of truth for the project rules. It applies to every AI coding agent, whether it implements changes or reviews them: an agent reviewing a pull request must verify that the changes comply with every rule below and report violations.

Agents pick this file up automatically. Mistral Vibe loads the repository-root `AGENTS.md` at startup, and nested `AGENTS.md` files when reading files below them. OpenAI Codex concatenates `AGENTS.md` files from the git root down to the current directory, files closer to the working directory taking precedence. GitHub Copilot reads `AGENTS.md` from the head branch of the pull request it works on. On-demand workflows can be added later as Agent Skills in `.agents/skills/`, the standard skills location shared by Vibe, Codex and Copilot.

## Language

- You may talk to the user in the user's language, for example French.
- Every file committed to git must be in English only: code, comments, commit messages, pull request descriptions, documentation.

## Goal and specifications

- This project is a drop-in replacement for the official Datadog agent. Everything implemented here must conform to the functional specifications in `specs/specs`. When those specifications are not precise enough, refer to the reference implementation sources in `specs/src/datadog-agent`.
- The specifications only define the external interface of the project: the data that is read, how it is processed, formatted and sent. The internal design is free and is documented with Doxygen comments next to the implementation or in `docs/`.
- This is a brand-new project with no users. Never keep backward compatibility with earlier versions of this codebase; the only compatibility that matters is conformance with the upstream Datadog agent specifications.

## Core architecture design

- The design of the core architecture (plugin system and ABI, configuration format and reflection, logging, asynchronous execution model, component manager and hot reload, IPC control plane) is documented in `docs/` — start at `docs/README.md`.
- Every implementation session must follow these design documents. When a change alters the design, update `docs/` in the same commit so the documents always reflect the code.

## Clean code

- Optimize code for human readability above everything else.
- Write the minimal code that satisfies the request. No over-engineering and no handling of purely hypothetical edge cases (YAGNI).
- Apply the classic clean-code principles: KISS, DRY, YAGNI, the five SOLID principles (Single Responsibility, Open/Closed, Liskov Substitution, Interface Segregation, Dependency Inversion), the Law of Demeter, Command-Query Separation, and the other GRASP and CUPID principles where relevant.
- Prefer small functions with meaningful names that each do one thing.
- After each task, and especially after iterative ones, do a simplification pass: remove dead code, unreachable branches and comments describing code that no longer exists, so that no trace of intermediate iterations remains. Implement only the strict minimum that was asked for.

## Comments and documentation

- Keep comments to the strict minimum. Prefer code that is clear on its own.
- Never leave comments about code that no longer exists.
- C++ code is documented with Doxygen comments, because the API documentation is generated with Doxygen. Document public interfaces briefly.

## Avoid special cases

- Do not multiply branches and special cases. Encode "no limit" as `std::numeric_limits<T>::max()`, never as a magic value such as `0` that callers must test for.
- Never store composite data encoded in a single `std::string` that would need to be parsed. Use structured types instead: a Docker image name, for example, is a small class with `registry`, `short_name` and `tag` fields, not the string `"datadog/agent:7.51.0"`.
- Never keep temporal data as `std::string` internally. Convert to `std::chrono::time_point` or `std::chrono::duration` as early as possible when reading data, and convert back to string as late as possible when producing output.

## Modern C++

- Use the most modern C++ possible: C++26 with the latest GCC and Clang. Never use a legacy construct when a modern replacement exists.
- Use `#pragma once` for project headers; the supported GCC and Clang versions
  implement it reliably.
- Prefer a leading return type when it is clearer and shorter. Use a trailing
  return type only when syntax requires it or it materially improves clarity.
- Raw pointers are forbidden. Use smart pointers (`std::unique_ptr`, `std::shared_ptr`), references, `std::optional`, `std::expected`, `std::span` and views. Manual `new` and `delete` are forbidden; use RAII for every resource.
- Aim for the strongest correctness guarantees C++ can offer, as close as possible to what Rust guarantees:
  - follow the C++ Core Guidelines safety profiles (Pro.Type, Pro.Bounds, Pro.Lifetime): no pointer arithmetic, no `reinterpret_cast`, no C-style casts, no unchecked indexing;
  - mark fallible functions `[[nodiscard]]`, use `[[assume]]` and `std::unreachable`, and use `const` and `constexpr` as much as possible;
  - use contracts (`pre(...)`, `post(...)`, and `post(result: ...)`) where the toolchain supports them;
  - use the C++26 features supported by our toolchain, such as `= delete("reason")` (see <https://en.cppreference.com/cpp/compiler_support/26>);
  - handle errors with `std::expected` and `std::optional` rather than error-prone manual state.
- Use the classic design patterns (the Gang of Four catalog: creational, structural and behavioral patterns) wherever a use case matches, and use inheritance and polymorphism wherever they apply.

## Dependencies

- Prefer the C++ standard library, even for features only available in the very latest version of the standard.
- If the standard library does not provide what is needed, use Boost next.
- Only then consider third-party libraries, choosing actively maintained and widely adopted ones, and add them through the vcpkg manifest (`vcpkg.json`).

## Build, tests and lint

- Build and test with the CMake presets, for example `cmake --workflow --preset dev` (configure, build and test in one command).
- Every change must keep the whole CI green: build and tests on every preset
  with every compiler that supports it, including the sanitizer presets, plus
  all linters (clang-format, clang-tidy, actionlint, yamllint,
  editorconfig-checker, cmake-lint, markdownlint).
- Add GTest unit tests for every new behavior and keep the coverage flow working.
- Run clang-format and clang-tidy locally before committing.
- Do not add `NOLINT`, formatter-off regions, linter exclusions, or warning
  suppressions unless the rule is objectively inapplicable. Keep every such
  exception local, name the rule, and explain why it is safe.
- CI must check every tracked project file with its applicable formatter and
  linter. Generated files, build directories, and the `specs` submodule are
  not project source files and must not be checked as such.

## Git workflow

- Work on a dedicated branch and open a draft pull request. Keep the CI green, then mark the pull request ready for review.
- Write commit messages in English, one logical change per commit, and squash intermediate iterations so the merged history keeps no trace of the working process. Never delete or rewrite the discussion history of a pull request.
- Commits materially authored by Codex must retain the `Co-authored-by: Codex <noreply@openai.com>` trailer when amended.

## Continuous improvement of these instructions

- When the user gives a correction or a clarification during a session and the rule is generalizable, add it to this `AGENTS.md` so that future sessions follow it without needing close supervision. This keeps the repository homogeneous over time.
