# SLAM in Degenerate Environments

## Motivation

State-of-the-art LiDAR-inertial odometry systems perform well in feature-rich indoor environments but degrade significantly in long, featureless corridors. The core issue is **sensor degeneracy**: corridor geometry is repetitive and self-similar, providing insufficient geometric constraints for point cloud registration. Without loop closure, drift compounds and the estimated trajectory and map become unreliable.

The fundamental question is not whether a specific algorithm works or fails — it is whether **sensor modalities themselves are insufficient** in degenerate environments, and whether loop closure is a genuine solution or merely a patch compensating for what the sensors cannot observe.

Degeneracy manifests in two compounding ways:
- **Geometric degeneracy**: the corridor axis is poorly constrained by lidar features — planar walls provide little information along the direction of travel
- **Perceptual aliasing**: repeated structure (same walls, same doors) makes loop closure unreliable even when it is attempted

Early observation from real data: without loop closure, drift accumulates rapidly in corridors. In feature-rich environments the same algorithms remain usable without loop closure. This suggests the answer is environment-dependent, and the goal of this work is to understand where that threshold lies.

Additionally, this work is conducted **without ground truth** trajectory or maps, which makes evaluation non-trivial and requires map-based metrics (e.g., ICP fitness scores, MME, submap consistency).

---

## Core Research Questions

1. **Is loop closure necessary, or is it masking sensor degeneracy?**
   In featureless corridors, does loop closure correct real drift, or does it create false positives due to perceptually identical environments?

2. **Can richer sensor modalities (vision, sensor fusion) reduce drift without loop closure?**
   If visual features provide geometric constraints that LiDAR cannot, can drift be sufficiently reduced so that loop closure becomes optional rather than mandatory?

3. **Does tight vs. loose sensor coupling matter in degenerate scenarios?**
   Super Odometry is loosely coupled. Does tight LiDAR-visual-inertial fusion (e.g., LVI-SAM) outperform it in corridors, and by how much?

4. **At what point does the environment become too degenerate for odometry alone?**
   Is there a measurable threshold of feature sparsity beyond which no odometry system can maintain acceptable drift without loop closure?

---

## Hypotheses

- **H1:** LiDAR-inertial odometry alone (without loop closure) will accumulate significant drift in corridor environments regardless of algorithm, due to geometric degeneracy.
- **H2:** Adding visual features (VINS-Mono or similar) as an additional modality will reduce drift even without loop closure, by providing texture and edge constraints unavailable to LiDAR.
- **H3:** Tightly coupled LiDAR-visual-inertial systems will outperform loosely coupled ones in degenerate corridors, because mutual sensor reinforcement constrains pose estimation more effectively.
- **H4:** Loop closure in self-similar corridors will generate false positives, making it unreliable as a standalone correction mechanism.

---

## Dataset

- **Environment:** Long indoor corridor, ~3 loops along the same path
- **Sensors:** LiDAR, IMU, (planned) camera
- **Ground truth:** Not available — evaluation via map-based metrics (ICP fitness, MME, submap consistency)

See [data_collection.md](data_collection.md) for how to collect data from the rover.

---

## Experiments

### Experiment 1 — Baseline Diagnostic: Super Odometry Without Loop Closure
**Goal:** Establish the failure mode. Quantify drift in the corridor using map-based metrics.
- Run Super Odometry on corridor dataset, loop closure **disabled**
- Measure drift using ICP fitness score between submaps and MME
- Compare map quality vs. indoor (feature-rich) environment run
- **Expected outcome:** Significant drift; map inconsistency after each loop

### Experiment 2 — LiDAR-Inertial Baselines Without Loop Closure
**Goal:** Determine if Super Odometry's performance is typical of LiDAR-inertial systems, or if other algorithms handle degeneracy better.
- Run alternative LiDAR-inertial odometry systems (e.g., KISS-ICP, FAST-LIO2) on the **same dataset**, loop closure **disabled**
- Evaluate using same map-based metrics
- **Expected outcome:** All LiDAR-inertial systems show similar drift, confirming it is a sensor/geometry problem, not an algorithm problem

### Experiment 3 — Effect of Loop Closure on LiDAR-Inertial Systems
**Goal:** Understand whether loop closure helps or introduces false positives in self-similar corridors.
- Re-run Experiments 1 and 2 with loop closure **enabled**
- Inspect loop closure events: are they geometrically correct or false positives?
- Measure map quality improvement (or degradation) after loop closure corrections
- **Expected outcome:** Loop closure partially corrects drift but may introduce false associations in repetitive sections

### Experiment 4 — Adding Visual Odometry (Loosely Coupled)
**Goal:** Test whether visual features reduce drift even in a loosely coupled configuration.
- Integrate VINS-Mono alongside Super Odometry (loosely coupled)
- Run on corridor dataset without loop closure
- Evaluate drift reduction vs. Experiment 1
- **Expected outcome:** Some drift reduction where visual texture exists; limited benefit in completely textureless stretches

### Experiment 5 — Tightly Coupled LiDAR-Visual-Inertial Baseline
**Goal:** Test whether tight coupling provides a meaningful advantage over Super Odometry's loose coupling.
- Run LVI-SAM (tightly coupled LiDAR-visual-inertial) on the same dataset, loop closure **disabled**
- Compare drift metrics against Experiments 1 and 4
- **Expected outcome:** Lower drift than loose coupling; mutual sensor reinforcement reduces degeneracy impact

### Experiment 6 — Full Comparison: All Systems With and Without Loop Closure
**Goal:** Comprehensive comparison across modalities and coupling strategies.

| System | Modality | Coupling | Loop Closure | Metric |
|---|---|---|---|---|
| Super Odometry | LiDAR-Inertial | Loose | Off / On | ICP, MME |
| KISS-ICP / FAST-LIO2 | LiDAR-Inertial | Tight | Off / On | ICP, MME |
| Super Odometry + VINS-Mono | LiDAR-Visual-Inertial | Loose | Off / On | ICP, MME |
| LVI-SAM | LiDAR-Visual-Inertial | Tight | Off / On | ICP, MME |

---

## Evaluation

No ground truth is available. Evaluation relies on:
- **Relative ATE / RPE** — drift measured over short segments
- **ICP fitness score** — alignment quality between submaps
- **MME (Map Mean Error)** — map consistency across multiple passes
- **Failure analysis** — understanding *how* and *when* algorithms diverge, not just *that* they do

---

## Open Questions & Risks

- **No ground truth:** All evaluation is relative — map consistency does not guarantee absolute accuracy.
- **False loop closures:** In self-similar corridors, loop closure may worsen results.
- **Camera calibration:** Adding vision requires careful extrinsic calibration with LiDAR.
- **Lighting:** Corridor lighting conditions affect visual feature extraction quality.
- **Computation:** Tight coupling is heavier — feasibility on robot hardware needs verification.

---

## Repo Structure

```
src/            # Algorithm implementations (submodules)
  SuperOdom/
launch/         # Launch files for data collection and recording
data/           # Collected datasets
scripts/        # Evaluation and analysis scripts
```
