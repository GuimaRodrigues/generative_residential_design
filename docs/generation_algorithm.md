# Generation algorithm

## 1. Feasibility

Before search, the engine validates positive site dimensions, non-negative setbacks, a non-empty buildable rectangle, supported floor count, valid room minima, available upper floors, per-floor locked area, total minimum area versus envelope capacity/maximum area, and whether each room can theoretically fit in the envelope. An obvious failure returns without consuming any candidate attempts.

## 2. Room normalization

Each `RoomRequirement.count` expands into individual `RoomInstance` values. IDs are stable by room type and serial—for example `bedroom_1`, `bedroom_2`, and `bedroom_3`. Each instance carries resolved target area and minimum area/dimensions from the editable requirement or centralized room metadata.

## 3. Floor assignment

Ground/upper locks are placed first. For a two-floor project, `any` rooms are shuffled by the attempt PRNG and assigned with a weighted balancing heuristic based on target area already assigned to each floor. One-floor projects assign every flexible room to floor zero.

## 4. Footprint selection

The ground floor starts from a rectangle entirely inside the buildable envelope. Its desired area is based on summed room targets with a small seeded variation and is also large enough to support the minimum/target area needed above. Width is sampled from a feasible range; height is derived from area.

When a garage is requested, it is reserved as a front-corner annex with a vehicle-oriented aspect, minimum street frontage, and direct contact with the configured street facade. The remaining full-depth rectangle becomes the habitable support zone, producing an L-shaped occupied ground floor rather than treating the garage as an arbitrary interior leaf.

Every upper footprint is generated inside that habitable support zone and anchored toward a rear/side edge, avoiding a visually floating centered box and leaving the garage as a one-story wing. Its placement must contain the lower stair core. After partitioning, compatible room assignments are exchanged deterministically when necessary so upper and lower stair rectangles overlap by a meaningful area. Dimensions and locations stay on the global generation grid.

## 5. Slicing tree and partitioning

`PartitionGenerator` recursively produces:

```text
SlicingTree
  Split(horizontal | vertical, actualRatio)
    RoomLeaf(room)
    Split(...)
```

At a branch, rooms are divided into two non-empty groups. The ideal ratio is the first group's summed target area divided by both groups' target area. A small seeded perturbation prevents every tree from converging to the same proportions. Orientation responds to the current rectangle's aspect and alternates during bounded retries. The split coordinate is snapped to 0.25 m, and recursion backtracks when a leaf cannot meet its minimum area and rotatable minimum side lengths.

This is genuine BSP/slicing generation; there are no canned plan coordinates.

## 6. Deterministic randomness

Every attempt seed is derived from the user seed and attempt index with explicit 32-bit mixing. All shuffles, assignments, footprint choices, group divisions, orientations, and split perturbations use `DeterministicRandom`. There are no uncontrolled `Random()` calls in the engine.

Therefore:

```text
requirements + generation config + seed → same candidates and ranking
```

The architectural scene derives a second deterministic appearance code from the
candidate seed and attempt. It selects one of four modern exterior palettes, one
of five facade compositions, and a gable, hip, or parapeted flat roof, with a
strong bias toward the latter for a contemporary residential language. Window
proportions respond to both room use and exterior style; facade variants control
frames, balconies, pergolas, screens, cladding, and material contrast. This keeps
replay stable while making candidates and newly generated seeds visually distinct
in 3D.

## 7. Hard validation

The validator checks:

- exact normalized room IDs/count
- finite positive rectangles
- every room inside the buildable envelope
- no positive-area room overlap on a floor
- minimum room area and rotatable minimum dimensions
- locked floor assignments
- every occupied upper footprint covered by actual occupied room area below
- each garage on the ground-floor street facade with sufficient vehicle frontage
- vertically overlapping stair cores when stairs exist on adjacent floors
- global grid alignment
- optional maximum total area

Invalid candidates are rejected and their first failure is aggregated into diagnostics.

## 8. Soft scoring

Valid candidates receive independently calculated 0–100 scores:

- **Relationships:** shared-wall adjacency and floor-normalized center distance for near/away/same/different-floor rules
- **Room proportions:** target-area fit plus aspect-ratio quality
- **Street orientation:** normalized center distance to the configured street edge
- **Compactness:** footprint proportions and two-floor footprint overlap
- **Floor preference:** satisfaction of preferred floors

The weighted overall score uses 30%, 28%, 15%, 17%, and 10% respectively. Enabled relationship weights are honored inside their category. Per-relationship values below 60 become visible warnings, but never invalidate a design.

## 9. Ranking

Geometry signatures deduplicate candidates. Valid candidates sort by descending overall score with a stable geometry-signature tie break, and only `displayTopCandidates` are returned. Selecting a candidate in the UI changes only view state; it does not regenerate.

## Optimization status

The MVP currently searches independent randomized slicing genomes. A retained genome and hill-climbing mutator are intentionally deferred rather than documented as implemented. The next engine step is to retain each tree with its candidate, apply subtree/order/orientation/ratio mutations, regenerate geometry, and accept only valid score improvements.
