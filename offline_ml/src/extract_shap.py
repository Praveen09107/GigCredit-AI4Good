"""Extract TreeSHAP values and binned lookup tables for GigCredit models."""

from __future__ import annotations

import json
import pickle

import numpy as np
import pandas as pd
import shap

from .config import (
    DATASET_PATH,
    FEATURE_COUNT,
    FEATURE_SLICES,
    MODEL_FILES,
    SHAP_LOOKUP_PATH,
)


def _bins(values: np.ndarray, shap_values: np.ndarray, bin_count: int = 10) -> dict[str, list[float]]:
    edges = np.quantile(values, np.linspace(0.0, 1.0, bin_count + 1)).tolist()
    means: list[float] = []
    for idx in range(bin_count):
        low = edges[idx]
        high = edges[idx + 1]
        if idx == bin_count - 1:
            mask = (values >= low) & (values <= high)
        else:
            mask = (values >= low) & (values < high)
        if mask.any():
            means.append(float(np.mean(shap_values[mask])))
        else:
            means.append(0.0)
    return {"edges": edges, "shap": means}


def main() -> None:
    if not DATASET_PATH.exists():
        raise FileNotFoundError("Run data_generator.py before extract_shap.py")

    df = pd.read_csv(DATASET_PATH)
    feature_columns = [f"f_{i:02d}" for i in range(FEATURE_COUNT)]
    x_full = df[feature_columns].to_numpy(dtype=float)

    output: dict[str, dict[str, dict[str, list[float]]]] = {"schema_version": "1.0", "pillars": {}}

    for pillar in ("p1", "p2", "p3", "p4", "p6"):
        model_path = MODEL_FILES[pillar]
        if not model_path.exists():
            raise FileNotFoundError(f"Missing model artifact: {model_path}")

        with model_path.open("rb") as file:
            model = pickle.load(file)

        start, end = FEATURE_SLICES[pillar]
        x = x_full[:, start:end]
        sample_size = min(300, x.shape[0])
        sample = x[:sample_size]

        explainer = shap.TreeExplainer(model)
        shap_values = explainer.shap_values(sample)
        if isinstance(shap_values, list):
            shap_values = shap_values[0]

        pillar_lookup: dict[str, dict[str, list[float]]] = {}
        for local_idx, global_idx in enumerate(range(start, end)):
            feature_name = f"f_{global_idx:02d}"
            pillar_lookup[feature_name] = _bins(
                values=sample[:, local_idx],
                shap_values=np.asarray(shap_values)[:, local_idx],
            )

        output["pillars"][pillar] = pillar_lookup

    with SHAP_LOOKUP_PATH.open("w", encoding="utf-8") as file:
        json.dump(output, file, indent=2)

    print(f"Wrote SHAP lookup: {SHAP_LOOKUP_PATH}")


if __name__ == "__main__":
    main()

