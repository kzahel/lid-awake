"""Finder layout for the signed Lid Awake distribution image."""

files = [(defines["app"], "Lid Awake.app")]
symlinks = {"Applications": "/Applications"}
format = "UDZO"

background = defines["background"]
window_rect = ((200, 200), (600, 340))
default_view = "icon-view"
show_toolbar = False
show_sidebar = False
show_status_bar = False
show_pathbar = False

icon_size = 112
text_size = 14
label_pos = "bottom"
arrange_by = None
icon_locations = {
    "Lid Awake.app": (150, 170),
    "Applications": (450, 170),
}
