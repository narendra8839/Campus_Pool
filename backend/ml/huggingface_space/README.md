---
title: Campus Pool Review Sentiment
sdk: gradio
app_file: app.py
app_port: 7860
---

# Campus Pool review sentiment

This Space serves the Campus Pool fine-tuned DistilBERT model through the
authenticated Gradio API endpoint `/gradio_api/call/predict`. Configure
`HF_MODEL_ID`, `HF_TOKEN`, and `SENTIMENT_API_KEY` in the Space settings before
startup.
