import os
import subprocess
import zipfile
from logic.android_helper import get_android_paths

def export_clip(video_path, start, end, output_path, progress_callback=None):
    """
    Industrial FFmpeg Clip Generation.
    Algorithm: No -c copy, proper libx264 encoding as requested.
    """
    # ffmpeg -i input.mp4 -ss START -to END -c:v libx264 -c:a aac -preset fast output.mp4
    cmd = [
        "ffmpeg", "-y",
        "-ss", str(start),
        "-t", str(end - start),
        "-i", video_path,
        "-c:v", "libx264",
        "-c:a", "aac",
        "-preset", "fast",
        "-crf", "20",
        output_path
    ]
    
    try:
        process = subprocess.Popen(cmd, stderr=subprocess.PIPE, universal_newlines=True)
        # Progress parsing could be added here if needed for individual clips
        process.wait()
        return True
    except Exception as e:
        print(f"Export Failure: {e}")
        return False

def create_zip_export(clip_paths, zip_name="ScenePack_Export.zip"):
    """Creates a ZIP archive of selected clips."""
    paths = get_android_paths()
    export_dir = os.path.join(paths["gallery"], "SceneCuts")
    os.makedirs(export_dir, exist_ok=True)
    
    zip_path = os.path.join(export_dir, zip_name)
    
    with zipfile.ZipFile(zip_path, 'w') as zipf:
        for file in clip_paths:
            if os.path.exists(file):
                zipf.write(file, os.path.basename(file))
    
    return zip_path
