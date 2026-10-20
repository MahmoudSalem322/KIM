# Kim development rules

- Implement one user-approved phase at a time. Phase 12 (Quality Assurance, Optimization & Release) is the final authorized phase; new work requires explicit approval.
- Inspect existing features and dependencies before changes. Preserve working behavior.
- Use feature-first presentation/domain/data boundaries, Riverpod and GoRouter.
- Prioritize Flutter Web. Keep runtime offline, local and free of backend or login.
- Support Arabic RTL and English, light/dark/system themes and the shared design system.
- Use exact financial representation; never double for monetary calculations.
- Persist real settings and future financial data. Use stable operation IDs and atomic idempotency.
- Add meaningful tests, run flutter analyze, flutter test and web validation before completion.
- Create feature/<descriptive-name> branches from current main for future features.
- Keep feature implementation and tests in its own scoped commits. Push only as authorized.
- Report changed files, completed behavior, verification and remaining limitations.

Phase 1 was reconstructed into a dependency-ordered branch chain because it began
as an empty local project. See docs/git-workflow.md for the historical bases.
