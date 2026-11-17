"""Rigid low-to-high registration and similarity fit of the high mesh to the ML06 game frame."""
import json

import numpy as np
from scipy.spatial import cKDTree

from paths import WORK

points = np.load(WORK / "01-prepared/points.npz")
low, high, ml06 = points["low"], points["high"], points["ml06"]


def rigid(source, target_tree, target, iterations, keep, allow_scale=False):
    moved = source.copy()
    total = np.eye(4)
    for _ in range(iterations):
        distance, index = target_tree.query(moved)
        mask = distance < np.percentile(distance, keep)
        a, b = moved[mask], target[index[mask]]
        ca, cb = a.mean(0), b.mean(0)
        u, singular, vt = np.linalg.svd((a - ca).T @ (b - cb))
        rotation = vt.T @ u.T
        if np.linalg.det(rotation) < 0:
            vt[-1] *= -1
            rotation = vt.T @ u.T
        scale = singular.sum() / ((a - ca) ** 2).sum() if allow_scale else 1.0
        step = np.eye(4)
        step[:3, :3] = scale * rotation
        step[:3, 3] = cb - scale * rotation @ ca
        moved = moved @ step[:3, :3].T + step[:3, 3]
        total = step @ total
    return total, moved


high_tree = cKDTree(high)
low_to_high, low_aligned = rigid(low, high_tree, high, 40, 90)
low_error = high_tree.query(low_aligned)[0]

ml06_tree = cKDTree(ml06)
candidates = []
for flip in (1.0, -1.0):
    start = np.eye(4)
    start[:3, :3] = np.diag([flip, flip, 1.0])
    rotated = high @ start[:3, :3].T
    scale = np.ptp(ml06[:, 1]) / np.ptp(rotated[:, 1])
    start[:3, :3] *= scale
    rotated *= scale
    start[:3, 3] = (ml06.min(0) + ml06.max(0)) / 2 - (rotated.min(0) + rotated.max(0)) / 2
    rotated += start[:3, 3]
    fit, moved = rigid(rotated, ml06_tree, ml06, 50, 85, True)
    forward = ml06_tree.query(moved)[0].mean()
    backward = cKDTree(moved).query(ml06)[0].mean()
    candidates.append((forward + backward, fit @ start, forward, backward, flip))
_, high_to_game, forward, backward, flip = min(candidates, key=lambda item: item[0])

report = {
    "coordinate_frame": "Blender Z-up; glTF export converts to Godot Y-up with muzzle on -Z",
    "low_to_high": low_to_high.tolist(),
    "high_to_game": high_to_game.tolist(),
    "game_scale": float(np.cbrt(np.linalg.det(high_to_game[:3, :3]))),
    "muzzle_flip": flip < 0,
    "low_to_high_mean_mm": float(low_error.mean() * 1000),
    "low_to_high_p95_mm": float(np.percentile(low_error, 95) * 1000),
    "high_to_ml06_mean_mm": float(forward * 1000),
    "ml06_to_high_mean_mm": float(backward * 1000),
}
(WORK / "01-prepared/alignment.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps({k: v for k, v in report.items() if not isinstance(v, list)}, indent=2))
