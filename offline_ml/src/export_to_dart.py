"""Export trained tree models to Dart using m2cgen."""

from __future__ import annotations

import pickle
import sys

try:
    import m2cgen as m2c
except ImportError as exc:
    raise RuntimeError(
        "m2cgen is not installed. Run: pip install -r offline_ml/requirements.txt"
    ) from exc

from .config import MODEL_FILES, OUTPUT_DART_FILES, ensure_directories


def _assert_model_constraints(name: str, model: object) -> None:
    if name in {"p1", "p2", "p3", "p4"}:
        params = model.get_params()
        if params.get("tree_method") != "exact":
            raise RuntimeError(f"{name}: tree_method must be exact")


def _wrap_dart(name: str, body: str) -> str:
    fn = f"score{name.upper()}"
    return (
        "double clamp01(double value) => value < 0.0 ? 0.0 : (value > 1.0 ? 1.0 : value);\n\n"
        f"double {fn}(List<double> features) {{\n"
        "  final value = "
        f"{body};\n"
        "  return clamp01(value);\n"
        "}\n"
    )


def main() -> None:
    ensure_directories()
    sys.setrecursionlimit(50000)

    for pillar, model_path in MODEL_FILES.items():
        if not model_path.exists():
            raise FileNotFoundError(f"Missing model for export: {model_path}")
        with model_path.open("rb") as file:
            model = pickle.load(file)

        _assert_model_constraints(pillar, model)
        body = m2c.export_to_dart(model)
        content = _wrap_dart(pillar, body.strip())
        OUTPUT_DART_FILES[pillar].write_text(content, encoding="utf-8")
        print(f"Exported {pillar} -> {OUTPUT_DART_FILES[pillar]}")


if __name__ == "__main__":
    main()

