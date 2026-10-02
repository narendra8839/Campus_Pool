"""Gradio Space for the fine-tuned Campus Pool review classifier."""

import hmac
import os
from typing import Any

import spaces
import gradio as gr
from transformers import pipeline


HF_MODEL_ID = os.environ.get("HF_MODEL_ID", "Naren88/Sentiment_Service").strip()
HF_TOKEN = os.environ.get("HF_TOKEN")
SENTIMENT_API_KEY = os.environ.get("SENTIMENT_API_KEY")

if not HF_MODEL_ID:
    raise RuntimeError("HF_MODEL_ID must be configured.")
if not SENTIMENT_API_KEY:
    raise RuntimeError("SENTIMENT_API_KEY must be configured.")

classifier: Any = pipeline(
    "text-classification",
    model=HF_MODEL_ID,
    tokenizer=HF_MODEL_ID,
    token=HF_TOKEN,
    device=0,
)


@spaces.GPU
def predict_review_sentiment(text: str, api_key: str) -> dict[str, Any]:
    if not isinstance(api_key, str) or not hmac.compare_digest(
        api_key,
        SENTIMENT_API_KEY,
    ):
        raise gr.Error("Invalid sentiment service credentials.")

    if not isinstance(text, str):
        raise gr.Error("Review text must be a string.")
    normalized_text = text.strip()
    if not normalized_text:
        raise gr.Error("Review text must not be blank.")

    result = classifier(normalized_text, truncation=True)[0]
    label = str(result["label"]).lower()
    if label not in {"negative", "neutral", "positive"}:
        raise gr.Error(f"Unexpected model label: {label}")

    return {"sentiment": label, "confidence": float(result["score"])}


with gr.Blocks(title="Campus Pool Review Sentiment") as demo:
    gr.Markdown("# Campus Pool Review Sentiment")
    review_text = gr.Textbox(label="Review")
    api_key = gr.Textbox(label="Service key", type="password")
    prediction = gr.JSON(label="Prediction")
    analyze_button = gr.Button("Analyze sentiment")
    analyze_button.click(
        fn=predict_review_sentiment,
        inputs=[review_text, api_key],
        outputs=prediction,
        api_name="predict",
    )


if __name__ == "__main__":
    demo.launch()
