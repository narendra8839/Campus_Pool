# Campus Pool review sentiment

The review sentiment model fine-tunes Hugging Face
[`distilbert/distilbert-base-uncased`](https://huggingface.co/distilbert/distilbert-base-uncased)
using review comments and their existing 1–5 star ratings. Labels are derived
consistently: 1–2 stars are **negative**, 3 stars are **neutral**, and 4–5 stars
are **positive**. The trained model and exported review data are local artifacts
and are excluded from git.

## Generate synthetic reviews and fine-tune

To train with the project's synthetic data (no database connection required), run
these commands from `backend/`:

```bash
npm run generate:synthetic
python -m pip install -r ml/requirements-ml.txt
npm run train:sentiment -- --data data/synthetic/reviews.csv
```

The generator creates varied synthetic comments for each star rating. The trainer
deduplicates exact comment text, excludes text that has conflicting ratings,
requires at least ten unique unambiguous comments in each sentiment class, and
uses a deterministic stratified holdout split. It saves the tokenizer, classifier,
label map, and evaluation metrics (accuracy, macro F1, and confusion matrix) to
`ml/model-output/distilbert-sentiment/`. Synthetic comments exercise the training
and inference pipeline only; metrics from them do not estimate performance on
genuine student feedback.

Training downloads `distilbert/distilbert-base-uncased` from Hugging Face on the
first run (network access is required); subsequent inference loads the saved
fine-tuned model locally.

To train with an approved review export instead, export only `rating` and
`comment` with `npm run export:reviews:sentiment`, then pass
`--data ml/data/reviews.csv` to the training command. This exporter requires
`DATABASE_URL` and does not include user identifiers. The minimum-data guard is
only protection against degenerate training data, not a claim that ten examples
per class are enough for production-quality results.

## Run inference and call the backend endpoint

After training, start the local model service from `backend/`:

```bash
npm run serve:sentiment
```

The service listens on port 8001 by default. Set the same random
`SENTIMENT_API_KEY` in the backend's `.env` and the shell running Uvicorn, and
set `SENTIMENT_SERVICE_URL=http://127.0.0.1:8001` in the backend. Authenticated
clients can then call:

```http
POST /api/reviews/sentiment
Authorization: Bearer <token>
Content-Type: application/json

{"text":"The driver was friendly and the ride was smooth."}
```

The response includes a sentiment label and model confidence. The endpoint
returns an explicit service-unavailable error if the Python service is not
running or cannot produce a prediction; review creation itself does not depend
on the sentiment service.

Set `SENTIMENT_MODEL_PATH` to use a model directory other than the default. The
Python inference service must be restarted after replacing the model.

## Deploy inference to Hugging Face Spaces

The included Gradio Space is in `ml/huggingface_space/`. Create a new Space with
the Gradio SDK, then upload these files from that folder to the Space repository
root: `README.md`, `requirements.txt`, and `app.py`. Docker is not required.
Hugging Face Spaces installs Gradio 6.29 and Hugging Face Hub 1.x; the Space
requirements therefore use Transformers 5.2+, because Transformers 4 requires
Hugging Face Hub below 1.0 and conflicts with Gradio 6.

In the Space settings, add these secrets:

- `HF_TOKEN`: a read-only token that can access the private model repository.
- `SENTIMENT_API_KEY`: a long, randomly generated shared secret. Configure the
  exact same value in the Vercel backend; do not commit it or put it in the
  Flutter app.

Add this Space variable:

- `HF_MODEL_ID=Naren88/Sentiment_Service`

The Space downloads the private model when it starts and listens on port 7860.
Wait for the build and startup to finish, then check
`https://<space-name>.hf.space/health`; it should return `{"status":"ok"}`.
The `/predict` endpoint requires the `X-Sentiment-Api-Key` header.

In Vercel's backend project settings, set:

- `SENTIMENT_SERVICE_URL=https://<space-name>.hf.space`
- `SENTIMENT_API_KEY` to the same shared secret configured in the Space.

Redeploy the backend after changing its environment variables. Test review
analysis in the app; if the Space has been idle, allow for its startup delay.
The unauthenticated health endpoint does not expose the private model ID or
prediction access.

## Existing ride recommendation model

`train_ncf.py` remains the separate offline booking-interaction trainer. Its
default input is `data/synthetic/{users,rides,bookings}.csv`; use `--data-dir`
for another export and `--output-dir` to change artifact location. PyTorch is
optional for that script alone: without it, the script writes a deterministic
popularity baseline.
