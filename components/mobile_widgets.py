import flet as ft

class EliteCell(ft.Container):
    """Production Surface with 16dp rounded corners and soft shadows."""
    def __init__(self, content, padding=16, **kwargs):
        super().__init__(
            content=content,
            padding=padding,
            border_radius=16,
            bgcolor="#0d0e1a",
            border=ft.border.all(1, "#1e2230"),
            shadow=ft.BoxShadow(
                spread_radius=1,
                blur_radius=10,
                color=ft.Colors.with_opacity(0.1, "black"),
            ),
            **kwargs
        )

class SceneItem(ft.Container):
    """Premium Clip Card with Play Overlay and Multi-Select Support."""
    def __init__(self, scene_id, start, end, thumbnail_path, on_select):
        self.scene_id = scene_id
        self.selected = False
        
        # UI Elements
        self.thumb = ft.Image(
            src=thumbnail_path if thumbnail_path else "",
            width=None,
            height=None,
            fit=ft.ImageFit.COVER,
            border_radius=12,
        )
        
        # Play Overlay Icon
        self.overlay = ft.Icon(
            ft.Icons.PLAY_CIRCLE_OUTLINE_ROUNDED, 
            color=ft.Colors.with_opacity(0.8, "white"), 
            size=40,
            visible=True
        )

        # Checkbox Indicator
        self.checkbox = ft.Icon(
            ft.Icons.CHECK_CIRCLE_ROUNDED,
            color="#5a4dff",
            size=24,
            visible=False
        )
        
        super().__init__(
            content=ft.Stack([
                ft.Column([
                    ft.Stack([
                        ft.Container(self.thumb, aspect_ratio=16/9, border_radius=12),
                        ft.Container(self.overlay, alignment=ft.alignment.center),
                        ft.Container(self.checkbox, top=10, right=10)
                    ]),
                    ft.Row([
                        ft.Text(f"#{scene_id + 1}", size=12, weight=ft.FontWeight.BOLD, color="#5a4dff"),
                        ft.Text(
                            f"{int(start//60):02d}:{int(start%60):02d} – {int(end//60):02d}:{int(end%60):02d}", 
                            size=12, color="#8a8fb5"
                        ),
                    ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN)
                ], tight=True, spacing=8),
            ]),
            padding=12,
            border_radius=16,
            bgcolor="#0d0e1a",
            border=ft.border.all(1, "#1e2230"),
            on_click=lambda _: on_select(self),
            animate=ft.Animation(200, ft.AnimationCurve.EASE_OUT)
        )

    def toggle_select(self):
        self.selected = not self.selected
        self.border = ft.border.all(2, "#5a4dff") if self.selected else ft.border.all(1, "#1e2230")
        self.checkbox.visible = self.selected
        self.bgcolor = ft.Colors.with_opacity(0.1, "#5a4dff") if self.selected else "#0d0e1a"
        self.update()

class ModernHeader(ft.Row):
    """Clinical Application Bar."""
    def __init__(self, title="SCENE PACK PRO"):
        super().__init__(
            controls=[
                ft.Icon(ft.Icons.SUBDIRECTORY_ARROW_RIGHT_ROUNDED, color="#5a4dff", size=24),
                ft.Text(
                    title, 
                    size=18, 
                    weight=ft.FontWeight.W_900, 
                    color="#e2e8f0",
                    style=ft.TextStyle(letter_spacing=1.5)
                ),
            ],
            alignment=ft.MainAxisAlignment.START,
            vertical_alignment=ft.CrossAxisAlignment.CENTER,
            height=64
        )
