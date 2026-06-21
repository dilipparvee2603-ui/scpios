import os
import cv2
import numpy as np
import threading
import time
from logic.android_helper import get_android_paths

class SceneDetector:
    """
    Production-Grade Content-Based Scene Detection.
    Algorithm: 160x90 Grayscale Pixel-Difference (Threshold = 27).
    """
    def __init__(self, on_progress=None, on_complete=None):
        self.on_progress = on_progress
        self.on_complete = on_complete
        self._is_running = False
        self.paths = get_android_paths()

    def start_detection(self, video_path, threshold=27.0):
        if self._is_running: return
        self._is_running = True
        thread = threading.Thread(target=self._run_detection, args=(video_path, threshold), daemon=True)
        thread.start()

    def _run_detection(self, video_path, threshold):
        try:
            cap = cv2.VideoCapture(video_path)
            fps = cap.get(cv2.CAP_PROP_FPS)
            total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
            
            if total_frames <= 0:
                raise ValueError("Invalid video file or metadata")

            prev_frame = None
            scenes = []
            last_change_sec = 0.0
            
            # Sample every 0.5s for efficiency while maintaining detection quality
            sample_step = max(1, int(fps * 0.5))
            
            for frame_idx in range(0, total_frames, sample_step):
                cap.set(cv2.CAP_PROP_POS_FRAMES, frame_idx)
                ret, frame = cap.read()
                if not ret: break
                
                # Algorithm: Resize -> Gray
                curr_frame = cv2.resize(frame, (160, 90))
                curr_frame = cv2.cvtColor(curr_frame, cv2.COLOR_BGR2GRAY)
                
                if prev_frame is not None:
                    # Algorithm: Compute pixel-wise difference
                    diff = cv2.absdiff(curr_frame, prev_frame)
                    mean_diff = cv2.mean(diff)[0]
                    
                    # Algorithm: If difference > Threshold (27)
                    curr_sec = frame_idx / fps
                    if mean_diff > threshold:
                        # Stability: Ignore transitions shorter than 1 second
                        if curr_sec - last_change_sec >= 1.0:
                            scenes.append({
                                "id": len(scenes),
                                "start": last_change_sec,
                                "end": curr_sec,
                                "thumbnail": self._generate_thumbnail(video_path, last_change_sec + 0.1, len(scenes))
                            })
                            last_change_sec = curr_sec
                
                prev_frame = curr_frame
                
                # Report Progress
                if self.on_progress:
                    percent = int((frame_idx / total_frames) * 100)
                    self.on_progress(percent)

            # Final scene
            total_sec = total_frames / fps
            if total_sec - last_change_sec >= 1.0:
                scenes.append({
                    "id": len(scenes),
                    "start": last_change_sec,
                    "end": total_sec,
                    "thumbnail": self._generate_thumbnail(video_path, last_change_sec + 0.1, len(scenes))
                })

            cap.release()
            if self.on_complete:
                self.on_complete(scenes)
                
        except Exception as e:
            print(f"Industrial Engine Failure: {e}")
            if self.on_complete: self.on_complete([])
        finally:
            self._is_running = False

    def _generate_thumbnail(self, video_path, timestamp, scene_id):
        thumb_dir = os.path.join(self.paths["cache"], "thumbnails")
        os.makedirs(thumb_dir, exist_ok=True)
        out_path = os.path.join(thumb_dir, f"thumb_{scene_id}.jpg")
        
        # Accurate clinical thumbnail extraction via FFmpeg
        import subprocess
        cmd = [
            "ffmpeg", "-y", "-ss", str(timestamp), "-i", video_path,
            "-vframes", "1", "-s", "320x180", "-f", "image2", out_path
        ]
        try:
            subprocess.run(cmd, capture_output=True, timeout=5)
            return out_path
        except:
            return None
