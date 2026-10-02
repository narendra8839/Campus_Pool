import csv
import tempfile
import unittest
from pathlib import Path

from .train_sentiment import label_for_rating, load_examples, stratified_split


class SentimentTrainingDataTests(unittest.TestCase):
    def test_rating_buckets_match_review_stars(self):
        self.assertEqual([label_for_rating(rating) for rating in range(1, 6)], [0, 0, 1, 2, 2])

    def test_non_integer_ratings_are_rejected(self):
        with self.assertRaisesRegex(ValueError, "whole number"):
            label_for_rating(3.5)

    def test_duplicate_text_with_conflicting_ratings_is_excluded(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "reviews.csv"
            with path.open("w", newline="", encoding="utf-8") as handle:
                writer = csv.DictWriter(handle, fieldnames=["rating", "comment"])
                writer.writeheader()
                writer.writerows([
                    {"rating": 1, "comment": "  Late ride "},
                    {"rating": 4, "comment": "late   ride"},
                    {"rating": 5, "comment": "Great ride"},
                ])

            examples, counts = load_examples(path)

        self.assertEqual(examples, [{"text": "Great ride", "label": 2}])
        self.assertEqual(counts["ambiguous_duplicate_texts"], 1)

    def test_stratified_split_rejects_insufficient_class_data(self):
        examples = [{"text": f"review {index}", "label": index % 3} for index in range(9)]
        with self.assertRaisesRegex(ValueError, "at least 10 unique"):
            stratified_split(examples, 0.2, 42)


if __name__ == "__main__":
    unittest.main()
