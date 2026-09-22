# Offline NCF training

From the repository root:

```bash
python backend/ml/train_ncf.py
```

The default input is `backend/data/synthetic/{users,rides,bookings}.csv`.
Only `ACCEPTED` and `COMPLETED` bookings are positive interactions and
`REJECTED` bookings are negative interactions; `PENDING` and `CANCELLED` are
excluded. Use `--data-dir` for an exported dataset and `--output-dir` to select
another artifact location.

PyTorch is optional. With `backend/ml/requirements-ml.txt` installed, the
script writes `ncf_model.pt`; without ML dependencies it writes a documented
popularity fallback. Both modes write `metadata.json` with counts and ROC-AUC /
PR-AUC when the test split contains both classes. Model output is intentionally
ignored by git.
