
import os
import logging
import redis
import threading
import time

from rq import get_current_job
from faster_whisper import WhisperModel

logging.basicConfig(level=logging.INFO)

redis_conn = redis.StrictRedis(
    host="localhost",
    port=6379,
    decode_responses=True
)

# Load model once when worker starts
model = WhisperModel(
    "base",
    device="cpu",
    compute_type="int8"
)


# -------------------------------------------------
# Smooth progress updater while transcription runs
# -------------------------------------------------
def fake_progress(job_id: str):

    progress = 20

    while progress < 90:

        redis_conn.set(f"progress:{job_id}", progress)
        redis_conn.set(f"stage:{job_id}", "Transcribing speech")

        time.sleep(1)
        progress += 2


# -------------------------------------------------
# Main transcription job
# -------------------------------------------------
def transcribe(video_path: str):

    job = get_current_job()
    job_id = job.id

    try:

        logging.info(f"Starting transcription: {video_path}")

        # Stage 1 — Preparing
        redis_conn.set(f"progress:{job_id}", 5)
        redis_conn.set(f"stage:{job_id}", "Preparing video")

        segments, info = model.transcribe(video_path)

        # Stage 2 — Extracting speech
        redis_conn.set(f"progress:{job_id}", 15)
        redis_conn.set(f"stage:{job_id}", "Extracting speech segments")

        # Start smooth progress thread
        progress_thread = threading.Thread(
            target=fake_progress,
            args=(job_id,),
            daemon=True
        )
        progress_thread.start()

        transcript = ""

        # Stream segments instead of converting to list
        for segment in segments:
            transcript += segment.text + " "

        # Stage 3 — Finalizing
        redis_conn.set(f"progress:{job_id}", 95)
        redis_conn.set(f"stage:{job_id}", "Finalizing transcript")

        result = transcript.strip()

        redis_conn.set(f"progress:{job_id}", 100)
        redis_conn.set(
            f"stage:{job_id}",
            "Transcription complete, opening transcript..."
        )

        logging.info(f"Transcription finished: {video_path}")

        return result

    finally:

        # Clean uploaded file
        if os.path.exists(video_path):
            os.remove(video_path)

