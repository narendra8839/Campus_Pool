"""Train the offline-first Campus Pool interaction model.

The script intentionally has no required third-party dependencies.  When PyTorch
is installed it trains a small neural collaborative filtering model; otherwise it
writes a deterministic popularity baseline so data preparation and evaluation
remain usable on a clean developer machine.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import random
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path
from typing import Any


POSITIVE_STATUSES = {"ACCEPTED", "COMPLETED"}
NEGATIVE_STATUSES = {"REJECTED"}
IGNORED_STATUSES = {"PENDING", "CANCELLED"}
FEATURE_NAMES = [
    "seats_requested", "fare_amount", "ride_available_seats", "ride_total_seats",
    "driver_rating", "driver_rating_count", "vehicle_seats", "distance_km",
    "departure_hour", "departure_weekday", "is_return_trip",
]


def _read_rows(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        return []
    if path.suffix.lower() == ".json":
        value = json.loads(path.read_text(encoding="utf-8"))
        return value if isinstance(value, list) else value.get("data", [])
    with path.open(newline="", encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))


def _read_dataset_file(directory: Path, stem: str) -> list[dict[str, Any]]:
    """Accept either the generator's CSV exports or equivalent JSON exports."""
    for suffix in (".csv", ".json"):
        rows = _read_rows(directory / (stem + suffix))
        if rows:
            return rows
    return []


def _number(value: Any, default: float = 0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _distance(a_lat: float, a_lng: float, b_lat: float, b_lng: float) -> float:
    # Equirectangular approximation is sufficient for local Pune routes.
    return math.sqrt(((a_lat - b_lat) * 111.0) ** 2 +
                     ((a_lng - b_lng) * 111.0 * math.cos(math.radians(a_lat))) ** 2)


def _date_parts(value: str) -> tuple[float, float]:
    try:
        date = datetime.fromisoformat(value.replace("Z", "+00:00"))
        return float(date.hour) + date.minute / 60.0, float(date.weekday())
    except (TypeError, ValueError):
        return 0.0, 0.0


def load_examples(data_dir: Path) -> tuple[list[dict[str, Any]], dict[str, int]]:
    users = {r.get("id"): r for r in _read_dataset_file(data_dir, "users")}
    rides = {r.get("id"): r for r in _read_dataset_file(data_dir, "rides")}
    examples: list[dict[str, Any]] = []
    counts = Counter()
    for booking in _read_dataset_file(data_dir, "bookings"):
        status = str(booking.get("status", "")).upper()
        if status in IGNORED_STATUSES or status not in POSITIVE_STATUSES | NEGATIVE_STATUSES:
            continue
        ride = rides.get(booking.get("rideId"), {})
        rider = users.get(booking.get("passengerId"), {})
        driver = users.get(ride.get("driverId"), {})
        hour, weekday = _date_parts(ride.get("departureTime", booking.get("createdAt", "")))
        numeric = [
            _number(booking.get("seatsRequested"), 1.0),
            _number(booking.get("fareAmount")),
            _number(ride.get("availableSeats")),
            _number(ride.get("totalSeats")),
            _number(driver.get("ratingAvg")),
            _number(driver.get("ratingCount")),
            _number(driver.get("vehicleSeats")),
            _distance(_number(booking.get("pickupLat")), _number(booking.get("pickupLng")),
                      _number(booking.get("dropLat")), _number(booking.get("dropLng"))),
            hour, weekday, 1.0 if ride.get("ridePurpose") == "return_from_college" else 0.0,
        ]
        examples.append({
            "rider_id": booking.get("passengerId", "unknown"),
            "driver_id": ride.get("driverId", "unknown"),
            "corridor_id": ride.get("corridorId", "unknown"),
            "numeric": numeric,
            "label": 1 if status in POSITIVE_STATUSES else 0,
        })
        counts[status] += 1
    return examples, dict(counts)


def _auc(labels: list[int], scores: list[float]) -> float | None:
    positives = [s for y, s in zip(labels, scores) if y == 1]
    negatives = [s for y, s in zip(labels, scores) if y == 0]
    if not positives or not negatives:
        return None
    wins = sum(1.0 if p > n else 0.5 if p == n else 0.0 for p in positives for n in negatives)
    return wins / (len(positives) * len(negatives))


def _average_precision(labels: list[int], scores: list[float]) -> float | None:
    total = sum(labels)
    if not total:
        return None
    order = sorted(range(len(scores)), key=lambda i: scores[i], reverse=True)
    hits = 0
    area = 0.0
    for rank, index in enumerate(order, 1):
        if labels[index]:
            hits += 1
            area += hits / rank
    return area / total


def _fallback_scores(train: list[dict[str, Any]], test: list[dict[str, Any]]) -> list[float]:
    global_rate = (sum(x["label"] for x in train) + 1.0) / (len(train) + 2.0)
    driver_totals: dict[str, list[int]] = defaultdict(lambda: [0, 0])
    rider_totals: dict[str, list[int]] = defaultdict(lambda: [0, 0])
    for row in train:
        for key, totals in ((row["driver_id"], driver_totals), (row["rider_id"], rider_totals)):
            totals[key][0] += row["label"]
            totals[key][1] += 1
    scores = []
    for row in test:
        d = driver_totals[row["driver_id"]]
        r = rider_totals[row["rider_id"]]
        d_rate = (d[0] + 1.0) / (d[1] + 2.0) if d[1] else global_rate
        r_rate = (r[0] + 1.0) / (r[1] + 2.0) if r[1] else global_rate
        scores.append(0.6 * d_rate + 0.3 * r_rate + 0.1 * global_rate)
    return scores


def train(examples: list[dict[str, Any]], output_dir: Path, seed: int, epochs: int) -> dict[str, Any]:
    if len(examples) < 2:
        raise ValueError("At least two ACCEPTED/COMPLETED/REJECTED interactions are required")
    rng = random.Random(seed)
    shuffled = examples[:]
    rng.shuffle(shuffled)
    split = max(1, min(len(shuffled) - 1, int(len(shuffled) * 0.8)))
    train_rows, test_rows = shuffled[:split], shuffled[split:]
    labels = [row["label"] for row in test_rows]
    mode = "popularity_fallback"
    scores: list[float]
    pair_scores: dict[str, float] = {}
    torch = None
    try:
        import torch  # type: ignore
        import torch.nn as nn  # type: ignore
        torch.manual_seed(seed)
        ids = {key: {v: i for i, v in enumerate(sorted({r[key] for r in examples}))}
               for key in ("rider_id", "driver_id", "corridor_id")}
        numeric = torch.tensor([r["numeric"] for r in train_rows], dtype=torch.float32)
        y = torch.tensor([r["label"] for r in train_rows], dtype=torch.float32)
        class NCF(nn.Module):
            def __init__(self) -> None:
                super().__init__()
                self.rider = nn.Embedding(len(ids["rider_id"]), 8)
                self.driver = nn.Embedding(len(ids["driver_id"]), 8)
                self.corridor = nn.Embedding(len(ids["corridor_id"]), 4)
                self.mlp = nn.Sequential(nn.Linear(20 + len(FEATURE_NAMES), 24),
                                         nn.ReLU(), nn.Linear(24, 1))

            def forward(self, rider: Any, driver: Any, corridor: Any, features: Any) -> Any:
                return self.mlp(torch.cat((self.rider(rider), self.driver(driver),
                                           self.corridor(corridor), features), dim=1)).squeeze(1)
        model = NCF()
        optimizer = torch.optim.Adam(model.parameters(), lr=0.01)
        for _ in range(epochs):
            optimizer.zero_grad()
            logits = model(torch.tensor([ids["rider_id"][r["rider_id"]] for r in train_rows]),
                           torch.tensor([ids["driver_id"][r["driver_id"]] for r in train_rows]),
                           torch.tensor([ids["corridor_id"][r["corridor_id"]] for r in train_rows]),
                           numeric)
            loss = nn.functional.binary_cross_entropy_with_logits(logits, y)
            loss.backward()
            optimizer.step()
        model.eval()
        with torch.no_grad():
            scores = torch.sigmoid(model(
                torch.tensor([ids["rider_id"][r["rider_id"]] for r in test_rows]),
                torch.tensor([ids["driver_id"][r["driver_id"]] for r in test_rows]),
                torch.tensor([ids["corridor_id"][r["corridor_id"]] for r in test_rows]),
                torch.tensor([r["numeric"] for r in test_rows], dtype=torch.float32),
            )).tolist()
            pair_rows = {}
            for row in examples:
                pair_rows.setdefault((row["rider_id"], row["driver_id"]), row)
            pair_scores = {
                f"{rider_id}:{driver_id}": float(torch.sigmoid(model(
                    torch.tensor([ids["rider_id"][rider_id]]),
                    torch.tensor([ids["driver_id"][driver_id]]),
                    torch.tensor([ids["corridor_id"][row["corridor_id"]]]),
                    torch.tensor([row["numeric"]], dtype=torch.float32),
                )).item())
                for (rider_id, driver_id), row in pair_rows.items()
            }
        output_dir.mkdir(parents=True, exist_ok=True)
        torch.save({"state_dict": model.state_dict(), "ids": ids, "feature_names": FEATURE_NAMES},
                   output_dir / "ncf_model.pt")
        mode = "pytorch_ncf"
    except (ImportError, ModuleNotFoundError, OSError):
        scores = _fallback_scores(train_rows, test_rows)
        fallback_scores = _fallback_scores(train_rows, examples)
        pair_scores = {
            f"{row['rider_id']}:{row['driver_id']}": score
            for row, score in zip(examples, fallback_scores)
        }
        output_dir.mkdir(parents=True, exist_ok=True)
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "ncf-model.json").write_text(json.dumps({
        "mode": mode,
        "feature_names": FEATURE_NAMES,
        "pairScores": pair_scores,
    }, indent=2), encoding="utf-8")
    metrics = {"roc_auc": _auc(labels, scores), "pr_auc": _average_precision(labels, scores)}
    metadata = {
        "mode": mode, "created_at": datetime.now().astimezone().isoformat(),
        "examples": len(examples), "train_examples": len(train_rows),
        "test_examples": len(test_rows), "positive_examples": sum(x["label"] for x in examples),
        "features": FEATURE_NAMES, "metrics": metrics, "seed": seed,
    }
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "metadata.json").write_text(json.dumps(metadata, indent=2), encoding="utf-8")
    return metadata


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data-dir", type=Path, default=Path(__file__).parents[1] / "data" / "synthetic")
    parser.add_argument("--output-dir", type=Path, default=Path(__file__).parent / "model-output")
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--epochs", type=int, default=12)
    args = parser.parse_args()
    examples, status_counts = load_examples(args.data_dir)
    metadata = train(examples, args.output_dir, args.seed, args.epochs)
    metadata["status_counts"] = status_counts
    (args.output_dir / "metadata.json").write_text(json.dumps(metadata, indent=2), encoding="utf-8")
    print(json.dumps(metadata, indent=2))


if __name__ == "__main__":
    main()
