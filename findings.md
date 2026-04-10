# SuperOdometry — Feature Matching & Trajectory Quality Findings

---

## 1. Metrics Overview

### 1.1 Feature Degeneracy Score (`eig_ratio`, `eig_min`)

The feature degeneracy score is computed per frame from the extracted feature point cloud
(surface/planar points, and corner points where available).  For each frame the 3D point
positions are assembled into an N×3 matrix, centred around their mean, and a 3×3 scatter
matrix `C = XᵀX` is formed.  Its eigenvalues `λ₁ ≤ λ₂ ≤ λ₃` describe the spatial
distribution of the features:

```
eig_ratio  =  λ₁ / λ₃       (range 0–1)
eig_min    =  λ₁
```

**Geometric interpretation**

| Shape of feature cloud | λ₁ | λ₂ | λ₃ | eig_ratio |
|---|---|---|---|---|
| Sphere — features spread in all directions | large | large | large | → 1 |
| Pancake — features lie in a plane | ≈ 0 | large | large | → 0 |
| Needle — features along a line | ≈ 0 | ≈ 0 | large | → 0 |

A **high** `eig_ratio` means the extracted features are **spatially rich** — they span all
three dimensions roughly equally.  A **low** `eig_ratio` means the feature cloud is
flat or linear, which typically indicates a geometrically degenerate scene (long corridor,
open field, featureless ceiling).

> **Important caveat.**  `eig_ratio` is a property of the *input point cloud geometry*,
> computed before any correspondence is established.  A high score tells you the scene
> looks rich to the sensor; it does **not** guarantee that the optimizer will be
> well-conditioned — that depends on how well those features can be matched to the map
> (see §3).

---

### 1.2 Hessian Condition Numbers (`hessian_pos_condition_num`, `hessian_ori_condition_num`)

After the Ceres optimizer converges, the pose covariance is estimated via
`ceres::Covariance` (DENSE_SVD on J^T J).  The condition numbers are:

```
hessian_pos_condition_num  =  √(λ_min / λ_max)   of the 3×3 position covariance block
hessian_ori_condition_num  =  √(λ_min / λ_max)   of the 3×3 orientation covariance block
```

Close to **1** — the optimizer had constraints in all translational / rotational directions.
Close to **0** — one or more DoF were barely constrained this scan.

Unlike `eig_ratio`, this is derived from the actual residual Jacobians, so it reflects
true constraint quality rather than scene geometry alone.

---

### 1.3 Per-axis Pose Variance (`hessian_var_x/y/z`, `hessian_var_roll/pitch/yaw`)

Diagonal entries of the 6×6 pose covariance in tangent space.  Units: m² (position),
rad² (orientation).  A large value in a specific axis means that axis was weakly
constrained by the scan — even if the overall condition number looks acceptable.

---

### 1.4 Point-to-Plane and Point-to-Line Residuals

After the final ICP iteration, for each matched feature the geometric distance between
the current scan point (projected with the solved pose) and its map correspondence is
computed:

- **`plane_residual_rms`** — RMS of signed distances from scan surface points to their
  fitted map planes (metres).
- **`edge_residual_rms`** — RMS of distances from scan edge points to their fitted map
  lines (metres).

Low values indicate tight registration; a gradual increase over time suggests map drift
or deteriorating correspondence quality.

---

### 1.5 Vote-Based Uncertainty (`uncertainty_x/y/z/roll/pitch/yaw`)

For each successfully matched plane, the alignment between the plane normal and each
world axis is measured.  Each match votes for the DoF it best constrains.  The
`uncertainty_*` fields are the normalised vote fractions scaled to [0, 1].

**High = more planes face that direction = more constraints in that DoF.**

These are a *geometric diversity* metric for the plane feature set — useful as a
scene descriptor but not a substitute for the Hessian-based values above (quality of
individual matches is not factored in, and edge features are excluded entirely).

---

## 2. Experiment: LOAM Features vs. Uniform Planar Downsample

### 2.1 Setup

Two feature extraction configurations were compared across outdoor and indoor runs:

| Configuration | Surface features | Edge/corner features |
|---|---|---|
| **LOAM** | Planar points (curvature-selected) | Edge/corner points (curvature-selected) |
| **Planar-only** | Uniformly downsampled surface points | None |

The LOAM configuration uses `use_loam_features: true` and adds curvature-based
corner detection on top of surface extraction.  The planar-only configuration uses
uniform voxel downsampling with no edge extraction.

### 2.2 Results — Feature Degeneracy Score

<!-- Insert: feature_degeneracy.png for LOAM vs planar-only (outdoor) -->
<!-- Insert: feature_degeneracy.png for LOAM vs planar-only (indoor) -->

The LOAM configuration produced a **higher `eig_ratio`** across both indoor and outdoor
runs.  This is expected: corner/edge points are spatially concentrated along structure
boundaries and object edges, which adds variance in directions the planar-only cloud
would miss.  By the metric alone, LOAM appears to give a richer feature set.

### 2.3 Results — Estimated Trajectory

<!-- Insert: trajectory_xy.png for LOAM vs planar-only (outdoor) -->
<!-- Insert: trajectory_xy.png for LOAM vs planar-only (indoor) -->

Despite the higher degeneracy score, the **LOAM configuration accumulated significantly
more drift** in both environments.  The estimated trajectory deviated further from
ground truth and showed larger loop closure error.

### 2.4 Discussion

The key observation is that **feature degeneracy score and trajectory quality are
decorrelated in this experiment**.  A high `eig_ratio` is a necessary but not sufficient
condition for good odometry.  What matters is not just whether features exist in all
directions, but whether those features can be **reliably associated** to the map.

Edge/corner features are inherently more sensitive to:
- Small changes in viewpoint angle between scans
- Occlusion and partial observations at object boundaries
- Discretisation effects at `mapping_line_resolution` in the voxel map

Surface points extracted by uniform downsampling, while geometrically less diverse per
frame, produce more **stable, repeatable correspondences** because they sample broad
planar regions that are consistently observed across multiple scans.

---

## 3. Indoor vs. Outdoor — Feature Richness and Data Association

### 3.1 Observation: Indoor is More Feature-Rich

<!-- Insert: stats_feature_counts.png — indoor vs outdoor comparison -->
<!-- Insert: feature_degeneracy.png — indoor vs outdoor comparison -->

Indoor environments consistently show higher feature counts and higher `eig_ratio`
than outdoor runs on the same platform.  Structured walls, floors, and furniture
create a dense distribution of well-conditioned plane normals in all directions,
while outdoor environments tend to have fewer horizontal constraints and more
open-sky regions with no returns.

### 3.2 Within-Environment: The Story is Data Association, Not Feature Count

Comparing runs **within the same environment** using only planar features (no LOAM),
differences in trajectory quality cannot be explained by feature count or degeneracy
score alone.  Runs with similar `eig_ratio` and similar feature counts can produce
measurably different drift rates.

<!-- Insert: plane_residual_rms over time — good run vs degraded run -->
<!-- Insert: hessian_condition_numbers over time — good run vs degraded run -->

The discriminating factor is **data association quality**:

- `plane_residual_rms` is higher in worse runs — scan points fit their map planes
  less tightly, indicating that correspondences are being established to the wrong
  or poorly-fitted map regions.
- `hessian_pos_condition_num` drops in worse runs — the optimizer has fewer
  well-distributed constraints even though the raw feature count is similar.
- `plane_assoc_dist_mean` is larger in worse runs — the nearest-neighbor search
  is accepting correspondences at greater distances, which increases the probability
  of wrong matches.

This points to **map quality** and **voxel resolution** (`mapping_plane_resolution`)
as the primary lever, not the number of extracted features.  A coarser map voxel size
merges distinct surfaces into a single averaged plane, degrading normal accuracy and
causing the optimizer to solve against incorrect geometry.

### 3.3 Open Questions

- [ ] What is the relationship between `plane_assoc_dist_mean` and drift rate quantitatively?
- [ ] Does increasing `LocalizationPlaneDistanceNbrNeighbors` (currently 5) improve normal
      estimation in sparse outdoor regions?
- [ ] Is the LOAM degradation due to the edge feature residuals specifically, or does adding
      edges change the balance of the Hessian and indirectly weaken the plane constraints?

---

## 4. Plots

### 4.1 Feature Degeneracy

<!-- results/bunker_outer_loop_3_v2/super_odom/analysis/feature_degeneracy.png -->

### 4.2 Residuals

<!-- results/bunker_outer_loop_3_v2/super_odom/analysis/residuals.png -->

### 4.3 Hessian Constraint Quality

<!-- results/bunker_outer_loop_3_v2/super_odom/analysis/hessian_constraint_quality.png -->
<!-- results/bunker_outer_loop_3_v2/super_odom/analysis/hessian_orientation_uncertainty.png -->

### 4.4 Trajectory

<!-- results/bunker_outer_loop_3_v2/super_odom/analysis/trajectory_xy.png -->

### 4.5 Plane Match Rejection Breakdown

<!-- results/bunker_outer_loop_3_v2/super_odom/analysis/stats_plane_rejection.png -->

---

## 5. Commentary and Next Steps

<!-- Space for experiment-specific notes, parameter changes to try, anomalies observed -->

---
