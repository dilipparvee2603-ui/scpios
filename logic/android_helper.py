import os
import platform

def get_android_paths():
    """
    Surgical Path Discovery for Android environments.
    Translates Flet/Android environment variables to usable paths.
    """
    paths = {
        "app_data": os.getenv("FLET_APP_STORAGE_DATA", os.path.expanduser("~")),
        "cache": os.getenv("FLET_APP_STORAGE_TEMP", os.path.join(os.path.expanduser("~"), "tmp")),
        "gallery": "/storage/emulated/0/Movies/SceneCuts" if is_android() else os.path.expanduser("~/Movies/SceneCuts")
    }
    
    # Ensure directories exist
    for key in ["app_data", "cache"]:
        if not os.path.exists(paths[key]):
            try:
                os.makedirs(paths[key], exist_ok=True)
            except:
                pass
                
    return paths

def is_android():
    return platform.system().lower() == "android" or os.environ.get("ANDROID_ROOT") is not None
