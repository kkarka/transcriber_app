const API_BASE = "http://localhost:8000";

export interface UploadResponse {
  job_id: string;
  status: string;
}

export interface StatusResponse {
  status: "processing" | "finished" | "failed";
  progress: number;
  result?: string;
  stage: string;
}

export async function uploadVideo(file: File): Promise<UploadResponse> {
  const formData = new FormData();
  formData.append("file", file);

  const response = await fetch(`${API_BASE}/transcribe`, {
    method: "POST",
    body: formData
  });

  if (!response.ok) {
    throw new Error("Upload failed");
  }

  return response.json();
}

export async function uploadYoutube(url: string) {

  const response = await fetch("http://localhost:8000/transcribe-youtube", {
    method: "POST",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify({ url })
  });

  if (!response.ok) {
    throw new Error("YouTube transcription failed");
  }

  return response.json();
}


export async function checkStatus(jobId: string): Promise<StatusResponse> {
  const response = await fetch(`${API_BASE}/status/${jobId}`);

  if (!response.ok) {
    throw new Error("Status check failed");
  }

  return response.json();
}


export async function cancelJob(jobId: string) {

  const response = await fetch(
    `http://localhost:8000/cancel/${jobId}`,
    {
      method: "POST"
    }
  );

  return response.json();
}

