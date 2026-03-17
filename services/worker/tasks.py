import os
import logging
import redis
import threading
import time
import yt_dlp
import uuid

from rq import get_current_job
from faster_whisper import WhisperModel

logging.basicConfig(level=logging.INFO)

# -------------------------------------------------
# 1. LAZY REDIS CONNECTION
# -------------------------------------------------
_redis_client = None

def get_redis():
    """Returns a Redis client, lazy-loaded so it doesn't block imports."""
    global _redis_client
    if _redis_client is None:
        host = os.getenv("REDIS_HOST", "redis") # Defaults to "redis" for Docker
        _redis_client = redis.StrictRedis(
            host=host, 
            port=6379, 
            decode_responses=True,
            socket_timeout=5 # Fails safely instead of hanging forever
        )
    return _redis_client


# -------------------------------------------------
# 2. LAZY AI MODEL
# -------------------------------------------------
# Only load globally if we are NOT in a testing environment
if os.getenv("ENV") != "testing":
    model = WhisperModel(
        "base",
        device="cpu",
        compute_type="int8",
        download_root="/models"
    )
else:
    model = None # Tests will mock this


# -------------------------------------------------
# 3. Smooth progress updater while transcription runs
# -------------------------------------------------
def fake_progress(job_id: str):
    r = get_redis()
    progress = 20

    while progress < 90:
        try:
            r.set(f"progress:{job_id}", progress)
            r.set(f"stage:{job_id}", "Transcribing speech")
        except redis.exceptions.ConnectionError:
            pass # Fail silently in background thread if Redis blips

        time.sleep(1)
        progress += 2


# -------------------------------------------------
# 4. Main transcription job
# -------------------------------------------------
def transcribe(video_path: str):
    r = get_redis()
    job = get_current_job()
    job_id = job.id if job else "test_job" # Safety fallback for unit tests

    try:
        logging.info(f"Starting transcription: {video_path}")

        # Stage 1 — Preparing
        r.set(f"progress:{job_id}", 5)
        r.set(f"stage:{job_id}", "Preparing video")

        segments, info = model.transcribe(video_path)

        # Stage 2 — Extracting speech
        r.set(f"progress:{job_id}", 15)
        r.set(f"stage:{job_id}", "Extracting speech segments")

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
        r.set(f"progress:{job_id}", 95)
        r.set(f"stage:{job_id}", "Finalizing transcript")

        result = transcript.strip()

        r.set(f"progress:{job_id}", 100)
        r.set(
            f"stage:{job_id}",
            "Transcription complete, opening transcript..."
        )

        logging.info(f"Transcription finished: {video_path}")
        return result

    finally:
        # Clean uploaded file
        if os.path.exists(video_path):
            os.remove(video_path)


# -------------------------------------------------
# 5. YouTube Download Job
# -------------------------------------------------
def transcribe_youtube_job(youtube_url: str):
    r = get_redis()
    job = get_current_job()
    job_id = job.id if job else "test_job" # Safety fallback for unit tests
    
    video_id = str(uuid.uuid4())
    # Ensure this matches your UPLOAD_DIR in the container
    output_path = os.path.join("/app/uploads", f"{video_id}.%(ext)s")

    try:
        r.set(f"progress:{job_id}", 2)
        r.set(f"stage:{job_id}", "Downloading YouTube video...")

        ydl_opts = {
            "format": "bestaudio/best",
            "outtmpl": output_path,
            "postprocessors": [{
                "key": "FFmpegExtractAudio",
                "preferredcodec": "wav",
                "preferredquality": "192"
            }],
            "quiet": True
        }

        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            ydl.download([youtube_url])

        audio_path = output_path.replace("%(ext)s", "wav")
        
        # Now call your existing transcription logic
        return transcribe(audio_path)

    except Exception as e:
        logging.error(f"YouTube Download Failed: {e}")
        try:
            r.set(f"stage:{job_id}", f"Error: {str(e)}")
        except redis.exceptions.ConnectionError:
            pass
        raise e