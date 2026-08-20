# Architecture

## Dependency direction

The code follows one dependency direction:

```text
Flutter presentation
        ↓
Application Cubits
        ↓
Generation entry point
        ↓
Pure Dart engine and domain
```

`lib/engine`, `lib/domain`, and the geometry/random portions of `lib/core` have no Flutter dependency. They can be called from tests, a command-line process, a future native isolate, Web Worker, or remote executor without changing the generation rules.

## Major layers

### Core

- `core/geometry` owns meter-based points, rectangles, grid functions, intersection, containment, adjacency, shared-wall length, bounds, and normalized distance.
- `core/random` owns the seeded xorshift32 generator. The implementation avoids VM-versus-JavaScript 64-bit differences.
- `core/serialization` owns the versioned project document, JSON codec, and domain-to-SVG exporter.
- `core/platform` conditionally selects browser file upload/download. No `dart:io` is used.

### Domain

The domain contains immutable sites, project metadata, room requirements, normalized room instances, spatial relationships, explicit hard/soft constraint types, generated rooms/floors/candidates, and score values. Coordinates and dimensions are meters. Domain objects never store screen pixels.

### Engine

- `PreflightValidator` rejects impossible briefs before search.
- `FloorPlanGenerator` owns the bounded deterministic candidate loop and ranking.
- `PartitionGenerator` builds explicit `RoomLeaf`/`SplitNode` slicing trees while assigning snapped geometry.
- `DesignValidator` evaluates all MVP hard invariants.
- `DesignScorer` evaluates isolated scoring categories and per-relationship details.

The current UI calls generation synchronously after first yielding one frame. Progress values are emitted by callbacks. Candidate limits keep the operation bounded. The call surface is deliberately narrow so a Worker-backed executor can replace this strategy later; no Flutter async behavior exists in the engine.

### Application state

- `ProjectCubit` owns the current editable project and generation settings.
- `GenerationCubit` owns only idle/generating/success/failure lifecycle and orchestration. It depends on the `GenerationExecutor` interface; `LocalGenerationExecutor` is the current browser-local implementation.
- `CandidateSelectionCubit` stores the selected ranked alternative without triggering generation.
- `FloorPlanCubit` stores floor and selected-room inspection state.

Pan/zoom transformation state stays local to the canvas widget because it is high-frequency ephemeral UI state.

### Presentation

The desktop workspace contains a requirements panel, a large `CustomPainter` plan canvas, and a ranked candidate/diagnostics panel. `FloorPlanPainter` computes a viewport transform from site meters to canvas pixels on every paint. Site, setback envelope, street edge, footprint, rooms, dimensions, and selection are rendered from domain geometry.

## Persistence boundary

`ProjectDocument` stores `formatVersion`, project metadata, site and room requirements, spatial preferences, numeric seed, and generation settings. `ProjectCodec` rejects malformed JSON and unsupported format versions. Explicit browser import/export is the source of persistence in this MVP; autosave is intentionally deferred.

SVG export is vector-native: it serializes site/envelope/room rectangles and text from meter geometry. It is not a canvas screenshot.

## Error handling

Feasibility errors are returned as values rather than thrown. Search failures include attempt counts and aggregated rejection reasons. UI-facing unexpected failures are caught by `GenerationCubit`. Import parsing is isolated and displayed without replacing a valid current project.
