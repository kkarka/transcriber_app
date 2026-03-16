# AI Video Transcription App

A full-stack AI transcription platform that converts **uploaded videos or YouTube links into text transcripts** using modern DevOps architecture.

The application uses **FastAPI, Redis, and Faster-Whisper** for backend processing and a **React + TypeScript frontend** for a modern user interface.

This project demonstrates a real-world **DevOps workflow** including asynchronous job processing, containerization readiness, and scalable architecture.

---

# Features

### Video Upload

• Upload video files directly from your computer
• Drag-and-drop file upload support
• Automatic video preview
• File validation and size limits

### YouTube Transcription

• Paste a YouTube video URL
• Automatic video preview with thumbnail
• Displays video metadata:
• Title
• Channel name
• Duration
• Loading skeleton UI while metadata loads

### AI Transcription

• Speech-to-text transcription using **Faster-Whisper**
• Background processing with **Redis Queue (RQ)**
• Progress tracking for transcription jobs

### User Interface

• Modern React UI
• Tailwind styling
• Upload and preview interface
• Error dialogs for invalid uploads

---

# Architecture

The application follows an **asynchronous job processing architecture**.

User Request → FastAPI API → Redis Queue → Worker → Whisper Model → Transcript Output

This architecture ensures that large video transcription tasks do not block API responses.

---

# Tech Stack

## Frontend

• React
• TypeScript
• Tailwind CSS
• Lucide Icons

## Backend

• FastAPI
• Python
• Faster-Whisper AI model

## Background Processing

• Redis
• RQ (Redis Queue workers)

## DevOps Tools

• Docker (planned)
• Terraform (planned)
• AWS Deployment (planned)

---

# Project Structure

```
video-transcriber
│
├── backend
│   ├── main.py
│   ├── worker.py
│   ├── requirements.txt
│   ├── uploads/
│   └── notes/
│
├── frontend
│   ├── src
│   │   ├── components
│   │   │   ├── UploadSection.tsx
│   │   │   ├── ProcessingView.tsx
│   │   │   └── TranscriptionResult.tsx
│   │   └── App.tsx
│
├── Dockerfile
├── docker-compose.yml
├── .gitignore
└── README.md
```

---

# How It Works

1. User uploads a video or provides a YouTube URL
2. The FastAPI backend receives the request
3. The job is pushed into a Redis queue
4. A worker processes the transcription using Faster-Whisper
5. The transcript is generated and returned to the frontend

---

# Running the Project Locally

## 1. Clone the Repository

```
git clone https://github.com/YOUR_USERNAME/ai-video-transcriber.git
cd ai-video-transcriber
```

---

## 2. Start Redis

Redis must be running for background jobs.

```
redis-server
```

---

## 3. Start Backend

```
cd backend
pip install -r requirements.txt
uvicorn main:app --reload
```

Backend will start at:

```
http://localhost:8000
```

---

## 4. Start Worker

In another terminal:

```
cd backend
rq worker
```

The worker will process transcription jobs.

---

## 5. Start Frontend

```
cd frontend
npm install
npm run dev
```

Frontend runs at:

```
http://localhost:5173
```

---

# Future Improvements

This project is designed to evolve into a **production-grade DevOps deployment**.

Planned upgrades include:

• Docker containerization
• Kubernetes deployment
• CI/CD pipeline
• AWS infrastructure with Terraform
• S3 video storage
• PostgreSQL transcript database
• Automatic subtitle generation (SRT / VTT)

---

# Learning Goals

This project demonstrates practical knowledge of:

• Asynchronous job processing
• AI inference pipelines
• React + FastAPI full-stack development
• Redis background workers
• DevOps-ready architecture

---

# License

This project is open source and available under the MIT License.
