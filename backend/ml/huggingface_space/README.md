---
title: Campus Pool Review Sentiment
sdk: gradio
app_file: app.py
app_port: 7860
---

# Campus Pool review sentiment API

This Space serves the Campus Pool fine-tuned DistilBERT model through an
authenticated FastAPI endpoint mounted alongside Gradio. Configure `HF_MODEL_ID`,
`HF_TOKEN`, and `SENTIMENT_API_KEY` in the Space settings before startup.
