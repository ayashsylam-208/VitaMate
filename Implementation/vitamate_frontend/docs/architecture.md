# Frontend Architecture Guardrails

## Intent

This document defines where code belongs after the cleanup pass. The goal is to
keep features easy to extend without turning screens or models into hidden
service layers.

## Controller Rules

- Controllers own loading flags, submit flags, derived UI state, and calls to
  repositories or APIs.
- Controllers may orchestrate side effects that are not UI-bound, such as
  syncing notification schedules after API state changes.
- Controllers must not depend on `BuildContext`, `Navigator`, or
  `ScaffoldMessenger`.

## Screen Rules

- Screens compose widgets, forms, and user interactions.
- Screens may navigate and show snackbars after awaiting controller calls.
- Screens should not parse raw `Map<String, dynamic>` payloads from the network.
- When a screen becomes large, extract cards, sections, dialogs, and bottom
  sheets into separate files in the same feature.

## Model Rules

- Models represent typed application data.
- Models may parse JSON and expose simple derived getters.
- Models should not perform I/O, navigation, storage writes, or widget work.

## Service and API Rules

- API classes convert HTTP requests and responses and keep endpoint contracts
  stable.
- Cross-feature infrastructure belongs in `lib/core`.
- Shared scheduling or persistence logic belongs in services, not duplicated in
  multiple controllers or screens.

## Backend Boundary Reminder

- Backend views should stay thin request/response layers.
- Aggregation and domain calculations belong in backend services and
  coordinators.
