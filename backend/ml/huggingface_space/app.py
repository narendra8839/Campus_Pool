"""Authenticated inference API for the fine-tuned DistilBERT review classifier."""

from contextlib import asynccontextmanager
import hmac
import os
from pathlib import Path
from typing import Any

import gradio as gr
import torch
from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel, Field
from transformers import pipeline
import uvicorn


MODEL_PATH = Path(
    os.environ.get(
        "SENTIMENT_MODEL_PATH",
        str(
            Path(__file__).resolve().parent.parent
            / "model-output"
            / "distilbert-sentiment"
        ),
    )
)
HF_MODEL_ID = os.environ.get("HF_MODEL_ID", "").strip()
classifier: Any = None


@asynccontextmanager
async def lifespan(_app: FastAPI):
    global classifier
    if not os.environ.get("SENTIMENT_API_KEY"):
        raise RuntimeError("SENTIMENT_API_KEY must be configured.")

    if HF_MODEL_ID:
        model_source = HF_MODEL_ID
        token = os.environ.get("HF_TOKEN")
    else:
        if not (MODEL_PATH / "config.json").is_file():
            raise RuntimeError(
                f"Fine-tuned model not found at {MODEL_PATH}. "
                "Set HF_MODEL_ID or train_sentiment.py first."
            )
        model_source = str(MODEL_PATH)
        token = None

    classifier = pipeline(
        "text-classification",
        model=model_source,
        tokenizer=model_source,
        token=token,
        device=0 if torch.cuda.is_available() else -1,
    )
    yield
    classifier = None


api = FastAPI(title="Campus Pool Review Sentiment", lifespan=lifespan)


class SentimentRequest(BaseModel):
    text: str = Field(min_length=1, max_length=5000)


@api.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@api.post("/predict")
def predict(
    request: SentimentRequest,
    x_sentiment_api_key: str | None = Header(default=None),
) -> dict[str, Any]:
    expected_api_key = os.environ.get("SENTIMENT_API_KEY")
    if not expected_api_key:
        raise HTTPException(
            status_code=503,
            detail="Sentiment authentication is not configured",
        )
    if x_sentiment_api_key is None or not hmac.compare_digest(
        x_sentiment_api_key,
        expected_api_key,
    ):
        raise HTTPException(status_code=401, detail="Invalid sentiment service credentials")
    if classifier is None:
        raise HTTPException(status_code=503, detail="Sentiment model is not loaded")
    text = request.text.strip()
    if not text:
        raise HTTPException(status_code=422, detail="Review text must not be blank")
    result = classifier(text, truncation=True)[0]
    label = str(result["label"]).lower()
    if label not in {"negative", "neutral", "positive"}:
        raise HTTPException(status_code=500, detail=f"Unexpected model label: {label}")
    return {"sentiment": label, "confidence": float(result["score"])}


demo = gr.Blocks(title="Campus Pool Review Sentiment")
app = gr.mount_gradio_app(api, demo, path="/")


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=7860)
