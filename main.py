import flet as ft
import os
import asyncio
import requests
from components.mobile_widgets import EliteCell, SceneItem, ModernHeader
from logic.detector import SceneDetector
from logic.exporter import export_clip, create_zip_export
from logic.android_helper import get_android_paths

async def main(page: ft.Page):
    # Setup Production OLED Theme
    page.title = "SCENEPACK PRO"
    page.bgcolor = "#07080f"
    page.theme_mode = ft.ThemeMode.DARK
    page.padding = 16
    page.horizontal_alignment = ft.CrossAxisAlignment.CENTER
    
    # State Registry
    state = {
        "video_path": None,
        "video_name": "",
        "video_size": "",
        "scenes": [],
        "selected_indices": set(),
        "paths": get_android_paths(),
        "app_state": "PICKER", # PICKER, PREVIEW, DETECTING, CLIPS, EXPORTING
        "progress": 0,
        "status_msg": "",
        "broadcast": None
    }

    # --- BROADCAST SYSTEM ---
    class BroadcastBanner(ft.Container):
        def __init__(self):
            super().__init__(
                height=0,
                bgcolor="#1a1c2e",
                padding=ft.padding.symmetric(horizontal=20),
                animate=ft.animation.Animation(400, ft.AnimationCurve.DECELERATE),
                clip_behavior=ft.ClipBehavior.ANTI_ALIAS,
                content=ft.Row([
                    ft.Icon(ft.Icons.CAMPAIGN_ROUNDED, color="#ff2d55", size=20),
                    ft.Text("", size=12, weight=ft.FontWeight.BOLD, color="white", expand=True),
                    ft.IconButton(ft.Icons.OPEN_IN_NEW_ROUNDED, icon_color="#ff2d55", icon_size=18, on_click=self.open_url)
                ], alignment=ft.MainAxisAlignment.CENTER)
            )
            self.url = None

        def show(self, text, msg_type="info", url=None):
            colors = {
                "update": "#2d1a20",
                "warning": "#2d241a",
                "info": "#1a1c2e"
            }
            icon_colors = {
                "update": "#ff2d55",
                "warning": "#f59e0b",
                "info": "#3b82f6"
            }
            self.bgcolor = colors.get(msg_type, "#1a1c2e")
            self.content.controls[0].color = icon_colors.get(msg_type, "#3b82f6")
            self.content.controls[1].value = text.upper()
            self.url = url
            self.content.controls[2].visible = bool(url)
            self.height = 50
            self.update()

        def open_url(self, e):
            if self.url:
                page.launch_url(self.url)

    broadcast_banner = BroadcastBanner()

    # --- UI COMPONENTS ---
    
    # Header
    header = ModernHeader("SCENE PACK PRO")

    # 1. PICKER SCREEN
    picker_view = ft.Column(
        [
            ft.Container(height=100),
            ft.Icon(ft.Icons.VIDEO_LIBRARY_ROUNDED, size=80, color="#5a4dff"),
            ft.Text("SCENE PACK", size=24, weight=ft.FontWeight.W_900, style=ft.TextStyle(letter_spacing=2)),
            ft.Text("Production-Grade Scene Detection", color="#8a8fb5", size=14),
            ft.Container(height=40),
            ft.Button(
                "SELECT VIDEO",
                icon=ft.Icons.ADD_ROUNDED,
                style=ft.ButtonStyle(
                    bgcolor="#5a4dff", color="white", padding=25,
                    shape=ft.RoundedRectangleBorder(radius=12)
                ),
                on_click=lambda _: file_picker.pick_files(file_type=ft.FilePickerFileType.VIDEO)
            )
        ],
        horizontal_alignment=ft.CrossAxisAlignment.CENTER,
        visible=True
    )

    # 2. PREVIEW / PROCESSING SCREEN
    preview_view = ft.Column(
        [
            ft.Container(
                content=ft.Video(
                    expand=True,
                    aspect_ratio=16/9,
                    autoplay=False,
                    filter_quality=ft.FilterQuality.HIGH
                ),
                border_radius=12,
                clip_behavior=ft.ClipBehavior.ANTI_ALIAS,
                bgcolor="#0d0e1a",
                height=250
            ),
            ft.Container(height=20),
            ft.Text(id="video_info", value="", size=14, color="#8a8fb5"),
            ft.Container(height=40),
            ft.Button(
                "DETECT SCENES",
                width=400,
                height=56,
                style=ft.ButtonStyle(
                    bgcolor="#5a4dff", color="white",
                    shape=ft.RoundedRectangleBorder(radius=16)
                ),
                on_click=lambda _: start_detection()
            )
        ],
        horizontal_alignment=ft.CrossAxisAlignment.CENTER,
        visible=False
    )

    # 3. DETECTING SCREEN (Overlay / Progress)
    progress_bar = ft.ProgressBar(width=350, color="#5a4dff", bgcolor="#11121d")
    progress_text = ft.Text("0%", size=14, weight=ft.FontWeight.BOLD)
    status_msg = ft.Text("Initializing Engine...", color="#8a8fb5")
    
    detecting_view = ft.Column(
        [
            ft.Container(height=100),
            ft.Text("ANALYZING VIDEO", size=20, weight=ft.FontWeight.W_900),
            ft.Container(height=20),
            ft.Stack([
                ft.Container(progress_bar, padding=ft.padding.only(top=10)),
                ft.Container(progress_text, alignment=ft.alignment.center_right, padding=ft.padding.only(bottom=20))
            ]),
            status_msg,
            ft.Container(height=40),
            ft.TextButton("CANCEL", on_click=lambda _: reset_app())
        ],
        horizontal_alignment=ft.CrossAxisAlignment.CENTER,
        visible=False
    )

    # 4. CLIPS SCREEN
    grid = ft.GridView(expand=True, runs_count=1, spacing=16, run_spacing=16)
    
    # Sticky Bottom Bar
    export_btn = ft.Button(
        "EXPORT ZIP",
        style=ft.ButtonStyle(bgcolor="#5a4dff", color="white", shape=ft.RoundedRectangleBorder(radius=12)),
        on_click=lambda _: handle_export(is_zip=True)
    )
    
    bottom_bar = ft.Container(
        content=ft.Row([
            ft.Text(id="selection_count", value="0 clips selected", weight=ft.FontWeight.BOLD),
            ft.Row([
                ft.IconButton(ft.Icons.SHARE_ROUNDED, on_click=lambda _: handle_export(is_zip=False)),
                export_btn
            ])
        ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN),
        padding=16,
        bgcolor="#0d0e1a",
        border=ft.border.only(top=ft.border.BorderSide(1, "#1e2230")),
        height=80,
        visible=False
    )

    clips_view = ft.Column([grid], expand=True, visible=False)

    # --- LOGIC ---

    async def on_file_result(e):
        if e.files:
            state["video_path"] = e.files[0].path
            state["video_name"] = e.files[0].name
            state["video_size"] = f"{e.files[0].size / 1024 / 1024:.1f} MB"
            
            # Update Preview UI
            preview_view.controls[2].value = f"{state['video_name']} ({state['video_size']})"
            preview_view.controls[0].content.playlist = [ft.VideoMedia(state["video_path"])]
            
            switch_screen("PREVIEW")
            page.update()

    file_picker = ft.FilePicker(on_result=on_file_result)
    page.overlay.append(file_picker)

    def switch_screen(new_state):
        state["app_state"] = new_state
        picker_view.visible = (new_state == "PICKER")
        preview_view.visible = (new_state == "PREVIEW")
        detecting_view.visible = (new_state == "DETECTING" or new_state == "EXPORTING")
        clips_view.visible = (new_state == "CLIPS")
        bottom_bar.visible = (new_state == "CLIPS")
        page.update()

    def start_detection():
        switch_screen("DETECTING")
        status_msg.value = "Content-Based Analysis..."
        detector = SceneDetector(on_progress=on_progress, on_complete=on_detection_complete)
        detector.start_detection(state["video_path"], threshold=27)

    def on_progress(p):
        progress_bar.value = p / 100
        progress_text.value = f"{p}%"
        page.update()

    def on_detection_complete(scenes):
        async def ui_sync():
            state["scenes"] = scenes
            grid.controls.clear()
            for scene in scenes:
                def toggle(obj):
                    obj.toggle_select()
                    if obj.selected: state["selected_indices"].add(obj.scene_id)
                    else: state["selected_indices"].remove(obj.scene_id)
                    bottom_bar.content.controls[0].value = f"{len(state['selected_indices'])} clips selected"
                    page.update()

                grid.controls.append(
                    SceneItem(
                        scene["id"], scene["start"], scene["end"], 
                        scene["thumbnail"], on_select=toggle
                    )
                )
            
            switch_screen("CLIPS")
            page.update()
        
        asyncio.run_coroutine_threadsafe(ui_sync(), asyncio.get_event_loop())

    async def handle_export(is_zip=True):
        if not state["selected_indices"]: return
        
        switch_screen("EXPORTING")
        status_msg.value = "Generating clips (libx264)..."
        page.update()
        
        clip_paths = []
        for i, idx in enumerate(state["selected_indices"]):
            scene = state["scenes"][idx]
            out_name = f"Clip_{idx+1}.mp4"
            out_path = os.path.join(state["paths"]["cache"], out_name)
            
            status_msg.value = f"Processing {i+1}/{len(state['selected_indices'])}..."
            on_progress(int((i / len(state["selected_indices"])) * 100))
            
            export_clip(state["video_path"], scene["start"], scene["end"], out_path)
            clip_paths.append(out_path)

        if is_zip:
            status_msg.value = "Creating ZIP Archive..."
            zip_path = create_zip_export(clip_paths)
            status_msg.value = f"Saved to: {os.path.basename(zip_path)}"
        else:
            status_msg.value = f"Generated {len(clip_paths)} clips in /Movies/SceneCuts/"
        
        await asyncio.sleep(2)
        switch_screen("CLIPS")

    def reset_app():
        state["selected_indices"].clear()
        switch_screen("PICKER")

    async def fetch_broadcast():
        FB_URL = "https://cfx-scenepack-creator-default-rtdb.firebaseio.com"
        FB_SECRET = "YH6mWhfrTk0SuHuLUOoX81xgJw5VxM91B3JdFiTf"
        while True:
            try:
                # Use a separate thread for requests to not block the event loop
                loop = asyncio.get_event_loop()
                response = await loop.run_in_executor(None, lambda: requests.get(f"{FB_URL}/broadcast.json?auth={FB_SECRET}", timeout=10))
                if response.status_code == 200:
                    data = response.json()
                    if data and data.get("message"):
                        broadcast_banner.show(data["message"], data.get("type", "info"), data.get("url"))
                    else:
                        broadcast_banner.height = 0
                        broadcast_banner.update()
            except Exception as e:
                print(f"Broadcast fetch failed: {e}")
            await asyncio.sleep(60) # Sync every minute

    asyncio.create_task(fetch_broadcast())

    # --- MAIN LAYOUT ---
    page.add(
        ft.Column([
            header,
            ft.Divider(color="#1e2230"),
            ft.Stack([
                picker_view,
                preview_view,
                detecting_view,
                clips_view
            ], expand=True)
        ], expand=True),
        bottom_bar
    )

if __name__ == "__main__":
    ft.run(main)
