import os
import shutil
import uuid
import yt_dlp

from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from redis import Redis
from rq.job import Job
from rq.exceptions import NoSuchJobError

from redis_queue import transcription_queue
from pydantic import BaseModel
from rq.command import send_stop_job_command


app = FastAPI()

class YoutubeRequest(BaseModel):
    url: str

# -------------------------
# CORS CONFIG
# -------------------------

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # # Allows port 5173 to talk to port 8000, change in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# -------------------------
# CONFIG
# -------------------------

UPLOAD_DIR = "uploads"
MAX_FILE_SIZE = 500 * 1024 * 1024  # 500MB

os.makedirs(UPLOAD_DIR, exist_ok=True)

redis_conn = Redis(host="redis", port=6379)

ALLOWED_EXTENSIONS = (".mp4", ".mov", ".mkv")

# -------------------------
# ROOT
# -------------------------

@app.get("/")
def read_root():
    return {"message": "Transcription API running"}

# -------------------------
# UPLOAD + QUEUE JOB
# -------------------------

@app.post("/transcribe")
async def transcribe_video(file: UploadFile = File(...)):

    filename = file.filename.lower()

    if not filename.endswith(ALLOWED_EXTENSIONS):
        raise HTTPException(
            status_code=400,
            detail="Unsupported file type"
        )

    unique_filename = f"{uuid.uuid4()}_{filename}"

    file_path = os.path.abspath(
        os.path.join(UPLOAD_DIR, unique_filename)
    )

    with open(file_path, "wb") as buffer:
        # shutil.copyfileobj(file.file, buffer)

        while chunk := await file.read(1024 * 1024):
            buffer.write(chunk)
            
    job = transcription_queue.enqueue(
        "tasks.transcribe",
        file_path,
        job_timeout="30m"
    )

    return {
        "job_id": job.id,
        "status": "processing"
    }


@app.post("/transcribe-youtube")
async def transcribe_youtube(data: YoutubeRequest):
# Just pass the URL to the worker; let the worker handle the download
    job = transcription_queue.enqueue(
        "tasks.transcribe_youtube_job",
        data.url,
        job_timeout="45m"
    )

    return {
        "job_id": job.id,
        "status": "processing"
    }


# -------------------------
# JOB STATUS
# -------------------------


@app.get("/status/{job_id}")
def get_status(job_id: str):

    try:
        job = Job.fetch(job_id, connection=redis_conn)
    except NoSuchJobError:
        raise HTTPException(
            status_code=404,
            detail="Job not found"
        )

    video_path = job.args[0]

    progress = redis_conn.get(f"progress:{job_id}")
    stage = redis_conn.get(f"stage:{job_id}")

    progress = int(progress) if progress else 0

    if job.is_finished:
        return {
            "status": "finished",
            "result": job.result,
            "progress": 100,
            "stage": "Completed"
        }

    if job.is_failed:
        return {
            "status": "failed",
            "progress": progress,
            "stage": "Failed"
        }

    return {
        "status": "processing",
        "progress": int(progress) if progress else 0,
        "stage": stage or "Processing video"
    }

# Cancel job endpoint (optional)
@app.post("/cancel/{job_id}")
def cancel_job(job_id: str):

    try:
        job = Job.fetch(job_id, connection=redis_conn)
    except NoSuchJobError:
        raise HTTPException(
            status_code=404,
            detail="Job not found"
        )

    send_stop_job_command(redis_conn, job_id)

    return {
        "status": "cancelled"
    }

