import { useState, useRef, useEffect } from "react";
import { FileVideo } from "lucide-react";
import { UploadSection } from "./components/UploadSection";
import { ProcessingView } from "./components/ProcessingView";
import { TranscriptionResult } from "./components/TranscriptionResult";
import { ErrorDialog } from "./components/ErrorDialog";
import { uploadVideo, checkStatus, uploadYoutube } from "../api/transcription";
import { cancelJob } from "../api/transcription";

type AppState = "upload" | "processing" | "result";

export default function App() {
  const [state, setState] = useState<AppState>("upload");
  const [fileName, setFileName] = useState("");
  const [transcription, setTranscription] = useState("");
  const [jobId, setJobId] = useState<string | null>(null);
  const [progress, setProgress] = useState(0);
  const [displayProgress, setDisplayProgress] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const [stage, setStage] = useState("");
  const pollingRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const handleStartTranscription = async (
    source: "upload" | "youtube",
    data: File | string
  ) => {

    // Reset previous job state
      setProgress(0);
      setDisplayProgress(0);
      setStage("Preparing video...");

    if (source === "upload" && data instanceof File) {

      const allowedTypes = [
        "video/mp4",
        "video/quicktime",
        "video/x-matroska",
        "video/x-msvideo",
        "video/webm"
      ];

      if (!allowedTypes.includes(data.type)) {
        setError(
          "Unsupported file format. Please upload MP4, MOV, MKV, AVI, or WEBM."
        );
        return;
      }

      if (data.size > 500 * 1024 * 1024) {
        setError("File too large. Maximum allowed size is 500MB.");
        return;
      }

      setFileName(data.name);

      try {
        const job = await uploadVideo(data);

        setJobId(job.job_id);
        setState("processing");

        pollStatus(job.job_id);

      } catch (err) {

        console.error("Upload failed", err);
        setError("Upload failed. Please try again.");
      }
    }

    if (source === "youtube" && typeof data === "string") {

      setFileName("YouTube Video");

      try {

        const job = await uploadYoutube(data);

        setJobId(job.job_id);
        setState("processing");

        pollStatus(job.job_id);

      } catch (err) {

        console.error("YouTube transcription failed", err);
        setError("Failed to process YouTube video. Please check the URL.");
      }
    }
  };

  useEffect(() => {
    const interval = setInterval(() => {
      setDisplayProgress((prev) => {
        if (prev >= progress) return prev;
        return prev + 1;
      });
    }, 30);

    return () => clearInterval(interval);
  }, [progress]);

  const pollStatus = (jobId: string) => {

    if (pollingRef.current) {
      clearInterval(pollingRef.current);
    }

    pollingRef.current = setInterval(async () => {

      try {

        const status = await checkStatus(jobId);

        if (status.progress !== undefined) {
          setProgress(status.progress);
        }

        setStage(status.stage || "");


        if (status.status === "finished") {

          if (pollingRef.current) clearInterval(pollingRef.current);

          setProgress(100);
          setTranscription(status.result || "");
          setState("result");
        }

        if (status.status === "failed") {

          if (pollingRef.current) clearInterval(pollingRef.current);

          setError("Transcription failed. Please try again.");
          setState("upload");
        }

      } catch (error) {

        console.error("Polling error:", error);
        setError("Network error while checking transcription status.");
      }

    }, 3000);
  };

  useEffect(() => {
    return () => {
      if (pollingRef.current) {
        clearInterval(pollingRef.current);
      }
    };
  }, []);

    const handleStartOver = () => {

      setState("upload");
      setFileName("");
      setTranscription("");
      setJobId(null);
      setProgress(0);

      if (pollingRef.current) {
        clearInterval(pollingRef.current);
      }
    };

    const handleCancel = async () => {

    if (!jobId) return;

    await cancelJob(jobId);

    if (pollingRef.current) {
      clearInterval(pollingRef.current);
    }

    setState("upload");
    setProgress(0);
  };

  return (
    <div className="min-h-screen bg-background flex flex-col">

      <header className="border-b border-border bg-card">
        <div className="max-w-7xl mx-auto px-6 py-6">
          <div className="flex items-center gap-3">

            <FileVideo className="w-8 h-8 text-primary" />

            <div>
              <h1>Video Transcription</h1>
              <p className="text-muted-foreground">
                Upload a video or paste a YouTube URL to get instant transcription notes
              </p>
            </div>

          </div>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-6 py-12 flex-grow">

        {state === "upload" && (
          <UploadSection onStartTranscription={handleStartTranscription} 
            onError={(msg) => setError(msg)} />
        )}

        {state === "processing" && (
          <ProcessingView
            fileName={fileName}
            progress={displayProgress}
            stage={stage}
            onCancel={handleCancel}
          />
        )}

        {state === "result" && (
          <TranscriptionResult
            transcription={transcription}
            fileName={fileName}
            onStartOver={handleStartOver}
          />
        )}

      </main>

      <footer className="border-t border-border mt-auto py-6">
        <div className="max-w-7xl mx-auto px-6 text-center text-muted-foreground">
          <p>
            Powered by AI transcription technology. Developed by Arka.
          </p>
        </div>
      </footer>

      {error && (
        <ErrorDialog
          message={error}
          onClose={() => setError(null)}
        />
      )}

    </div>
  );
}

