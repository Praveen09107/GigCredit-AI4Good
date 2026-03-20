"""Shared configuration and constants for the Offline ML pipeline."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC_DIR = ROOT / "src"
DATA_DIR = ROOT / "data"
OUTPUT_DIR = ROOT / "output"
MODELS_DIR = ROOT / "models"

RANDOM_SEED = 42
PROFILE_COUNT_DEFAULT = 15_000
FEATURE_COUNT = 95
META_INPUT_LENGTH = 44

WORK_TYPE_VALUES = [
	"platform",
	"vendor",
	"tradesperson",
	"freelancer",
]

WORK_TYPE_SPLIT = {
	"platform": 0.35,
	"vendor": 0.25,
	"tradesperson": 0.25,
	"freelancer": 0.15,
}

FEATURE_SLICES = {
	"p1": (0, 13),
	"p2": (13, 28),
	"p3": (28, 37),
	"p4": (37, 49),
	"p5": (49, 67),
	"p6": (67, 78),
	"p7": (78, 88),
	"p8": (88, 95),
}

MODEL_FILES = {
	"p1": MODELS_DIR / "p1.pkl",
	"p2": MODELS_DIR / "p2.pkl",
	"p3": MODELS_DIR / "p3.pkl",
	"p4": MODELS_DIR / "p4.pkl",
	"p5": MODELS_DIR / "p5.pkl",
	"p6": MODELS_DIR / "p6.pkl",
	"p7": MODELS_DIR / "p7.pkl",
	"p8": MODELS_DIR / "p8.pkl",
}

OUTPUT_DART_FILES = {
	"p1": OUTPUT_DIR / "p1_scorer.dart",
	"p2": OUTPUT_DIR / "p2_scorer.dart",
	"p3": OUTPUT_DIR / "p3_scorer.dart",
	"p4": OUTPUT_DIR / "p4_scorer.dart",
	"p5": OUTPUT_DIR / "p5_scorer.dart",
	"p6": OUTPUT_DIR / "p6_scorer.dart",
	"p7": OUTPUT_DIR / "p7_scorer.dart",
	"p8": OUTPUT_DIR / "p8_scorer.dart",
}

DATASET_PATH = DATA_DIR / "synthetic_profiles.csv"
GENERATION_CONFIG_PATH = DATA_DIR / "generation_config.json"
SCHEMA_MANIFEST_PATH = DATA_DIR / "schema_manifest.json"
TRAINING_REPORT_PATH = DATA_DIR / "training_report.json"
SHAP_LOOKUP_PATH = DATA_DIR / "shap_lookup.json"
META_COEFFICIENTS_PATH = DATA_DIR / "meta_coefficients.json"
META_TRAINING_REPORT_PATH = DATA_DIR / "meta_training_report.json"
STATE_INCOME_ANCHORS_PATH = DATA_DIR / "state_income_anchors.json"
FEATURE_MEANS_PATH = DATA_DIR / "feature_means.json"
VALIDATION_REPORT_PATH = DATA_DIR / "validation_report.json"
REAL_READY_EVAL_REPORT_PATH = DATA_DIR / "real_ready_evaluation_report.json"


def ensure_directories() -> None:
	for directory in (DATA_DIR, OUTPUT_DIR, MODELS_DIR):
		directory.mkdir(parents=True, exist_ok=True)

