"""Fine-tune a Hugging Face DistilBERT classifier using Campus Pool reviews."""

from __future__ import annotations

import argparse
import csv
import json
import math
import random
import re
import unicodedata
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


LABELS = ("negative", "neutral", "positive")
DEFAULT_DATA = Path(__file__).resolve().parent / "data" / "reviews.csv"
DEFAULT_OUTPUT = Path(__file__).resolve().parent / "model-output" / "distilbert-sentiment"
MIN_EXAMPLES_PER_CLASS = 10


def label_for_rating(rating: Any) -> int:
    try:
        numeric_rating = float(rating)
    except (TypeError, ValueError) as error:
        raise ValueError(f"Invalid review rating: {rating!r}") from error
    if not math.isfinite(numeric_rating) or not numeric_rating.is_integer():
        raise ValueError(f"Review rating must be a whole number: {rating!r}")
    if numeric_rating < 1 or numeric_rating > 5:
        raise ValueError(f"Review rating must be between 1 and 5: {rating!r}")
    if numeric_rating <= 2:
        return 0
    if numeric_rating == 3:
        return 1
    return 2


def _read_rows(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        raise FileNotFoundError(f"Review dataset not found: {path}")
    if path.suffix.lower() == ".json":
        value = json.loads(path.read_text(encoding="utf-8"))
        if isinstance(value, dict):
            value = value.get("data", [])
        if not isinstance(value, list):
            raise ValueError("JSON review data must be a list or an object with a data list")
        return value
    with path.open(newline="", encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))


def load_examples(path: Path) -> tuple[list[dict[str, Any]], dict[str, int]]:
    """Load, validate, and deduplicate reviews without carrying user identifiers."""
    rows = _read_rows(path)
    by_text: dict[str, tuple[str, int]] = {}
    ambiguous: set[str] = set()
    discarded_empty = 0

    for index, row in enumerate(rows, start=1):
        if not isinstance(row, dict):
            raise ValueError(f"Review row {index} must be an object with rating and comment fields")
        comment = unicodedata.normalize("NFKC", str(row.get("comment") or ""))
        comment = re.sub(r"\s+", " ", comment).strip()
        if not comment:
            discarded_empty += 1
            continue
        label = label_for_rating(row.get("rating"))
        key = comment.casefold()
        existing = by_text.get(key)
        if existing and existing[1] != label:
            ambiguous.add(key)
        else:
            by_text[key] = (comment, label)

    examples = [
        {"text": text, "label": label}
        for key, (text, label) in by_text.items()
        if key not in ambiguous
    ]
    counts = Counter(example["label"] for example in examples)
    return examples, {
        "source_rows": len(rows),
        "unique_examples": len(examples),
        "ambiguous_duplicate_texts": len(ambiguous),
        "discarded_empty_comments": discarded_empty,
        "negative": counts[0],
        "neutral": counts[1],
        "positive": counts[2],
    }


def stratified_split(
    examples: list[dict[str, Any]], test_fraction: float, seed: int
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    grouped: dict[int, list[dict[str, Any]]] = defaultdict(list)
    for example in examples:
        grouped[example["label"]].append(example)

    missing = [LABELS[label] for label in range(len(LABELS)) if not grouped[label]]
    if missing:
        raise ValueError(f"Training requires all three rating classes; missing: {', '.join(missing)}")
    too_small = [
        f"{LABELS[label]}={len(grouped[label])}"
        for label in range(len(LABELS))
        if len(grouped[label]) < MIN_EXAMPLES_PER_CLASS
    ]
    if too_small:
        raise ValueError(
            f"Need at least {MIN_EXAMPLES_PER_CLASS} unique, unambiguous comments per class; "
            f"found {', '.join(too_small)}. Export more real reviews before training."
        )

    randomizer = random.Random(seed)
    train: list[dict[str, Any]] = []
    test: list[dict[str, Any]] = []
    for label in range(len(LABELS)):
        rows = grouped[label][:]
        randomizer.shuffle(rows)
        test_count = max(1, min(len(rows) - 1, round(len(rows) * test_fraction)))
        test.extend(rows[:test_count])
        train.extend(rows[test_count:])
    randomizer.shuffle(train)
    randomizer.shuffle(test)
    return train, test


def _evaluate(predictions: list[int], labels: list[int]) -> dict[str, Any]:
    matrix = [[0 for _ in LABELS] for _ in LABELS]
    for actual, predicted in zip(labels, predictions):
        matrix[actual][predicted] += 1
    per_class_f1 = []
    for label in range(len(LABELS)):
        true_positive = matrix[label][label]
        false_positive = sum(matrix[actual][label] for actual in range(len(LABELS)) if actual != label)
        false_negative = sum(matrix[label][predicted] for predicted in range(len(LABELS)) if predicted != label)
        denominator = 2 * true_positive + false_positive + false_negative
        per_class_f1.append((2 * true_positive / denominator) if denominator else 0.0)
    return {
        "accuracy": sum(actual == predicted for actual, predicted in zip(labels, predictions)) / len(labels),
        "macro_f1": sum(per_class_f1) / len(LABELS),
        "labels": list(LABELS),
        "confusion_matrix": matrix,
    }


def train(args: argparse.Namespace) -> dict[str, Any]:
    examples, data_counts = load_examples(args.data)
    train_rows, test_rows = stratified_split(examples, args.test_fraction, args.seed)

    try:
        import torch
        from torch.utils.data import DataLoader, Dataset
        from transformers import (
            AutoModelForSequenceClassification,
            AutoTokenizer,
        )
    except ImportError as error:
        raise RuntimeError(
            "ML dependencies are missing. Install them with "
            "'python -m pip install -r backend/ml/requirements-ml.txt'."
        ) from error

    random.seed(args.seed)
    torch.manual_seed(args.seed)

    label_to_id = {label: index for index, label in enumerate(LABELS)}
    tokenizer = AutoTokenizer.from_pretrained(args.base_model)
    model = AutoModelForSequenceClassification.from_pretrained(
        args.base_model,
        num_labels=len(LABELS),
        id2label={index: label for index, label in enumerate(LABELS)},
        label2id=label_to_id,
    )

    class ReviewDataset(Dataset):
        def __init__(self, rows: list[dict[str, Any]]) -> None:
            self.encodings = tokenizer(
                [row["text"] for row in rows],
                truncation=True,
                padding="max_length",
                max_length=args.max_length,
                return_tensors="pt",
            )
            self.labels = torch.tensor([row["label"] for row in rows], dtype=torch.long)

        def __len__(self) -> int:
            return len(self.labels)

        def __getitem__(self, index: int) -> dict[str, Any]:
            return {
                "input_ids": self.encodings["input_ids"][index],
                "attention_mask": self.encodings["attention_mask"][index],
                "labels": self.labels[index],
            }

    train_dataset = ReviewDataset(train_rows)
    test_dataset = ReviewDataset(test_rows)
    train_loader = DataLoader(train_dataset, batch_size=args.batch_size, shuffle=True)
    test_loader = DataLoader(test_dataset, batch_size=args.batch_size)
    class_counts = Counter(row["label"] for row in train_rows)
    class_weights = torch.tensor(
        [len(train_rows) / (len(LABELS) * class_counts[index]) for index in range(len(LABELS))],
        dtype=torch.float,
    )
    optimizer = torch.optim.AdamW(model.parameters(), lr=args.learning_rate)
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model.to(device)

    for epoch in range(args.epochs):
        model.train()
        total_loss = 0.0
        for batch in train_loader:
            batch = {key: value.to(device) for key, value in batch.items()}
            optimizer.zero_grad()
            outputs = model(
                input_ids=batch["input_ids"],
                attention_mask=batch["attention_mask"],
            )
            loss = torch.nn.functional.cross_entropy(
                outputs.logits, batch["labels"], weight=class_weights.to(device)
            )
            loss.backward()
            optimizer.step()
            total_loss += loss.item()
        print(f"Epoch {epoch + 1}/{args.epochs} - loss: {total_loss / len(train_loader):.4f}")

    model.eval()
    predictions: list[int] = []
    actual_labels: list[int] = []
    with torch.no_grad():
        for batch in test_loader:
            outputs = model(
                input_ids=batch["input_ids"].to(device),
                attention_mask=batch["attention_mask"].to(device),
            )
            predictions.extend(outputs.logits.argmax(dim=1).cpu().tolist())
            actual_labels.extend(batch["labels"].tolist())

    metrics = _evaluate(predictions, actual_labels)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    model.save_pretrained(args.output_dir)
    tokenizer.save_pretrained(args.output_dir)
    metadata = {
        "base_model": args.base_model,
        "labels": list(LABELS),
        "labeling_rule": {"negative": "ratings 1-2", "neutral": "rating 3", "positive": "ratings 4-5"},
        "trained_at": datetime.now(timezone.utc).isoformat(),
        "device": str(device),
        "epochs": args.epochs,
        "max_length": args.max_length,
        "data": data_counts,
        "train_examples": len(train_rows),
        "test_examples": len(test_rows),
        "evaluation": metrics,
    }
    (args.output_dir / "metadata.json").write_text(
        json.dumps(metadata, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps({"model_dir": str(args.output_dir), "evaluation": metrics}, indent=2))
    return metadata


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data", type=Path, default=DEFAULT_DATA, help="CSV or JSON review export")
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--base-model", default="distilbert/distilbert-base-uncased")
    parser.add_argument("--epochs", type=int, default=3)
    parser.add_argument("--batch-size", type=int, default=8)
    parser.add_argument("--max-length", type=int, default=256)
    parser.add_argument("--learning-rate", type=float, default=2e-5)
    parser.add_argument("--test-fraction", type=float, default=0.2)
    parser.add_argument("--seed", type=int, default=42)
    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    if args.epochs < 1 or args.batch_size < 1 or args.max_length < 1:
        parser.error("epochs, batch-size, and max-length must be positive")
    if not 0 < args.test_fraction < 1:
        parser.error("test-fraction must be between 0 and 1")
    try:
        train(args)
    except (FileNotFoundError, ValueError, RuntimeError) as error:
        parser.error(str(error))


if __name__ == "__main__":
    main()
