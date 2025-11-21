#!/usr/bin/env python3
import i3ipc
import sys
import html
import json
import os
import time
import threading

XDG_CONFIG_HOME = os.environ.get("XDG_CONFIG_HOME", os.path.join(os.path.expanduser("~"), ".config"))
CONFIG_FILE = os.path.join(XDG_CONFIG_HOME, "sway", "tab_colors.json")
COLOR_RULES = []
LAST_MTIME = 0
LAST_ERROR = ""

def load_config():
    global COLOR_RULES, LAST_MTIME, LAST_ERROR
    try:
        if not os.path.exists(CONFIG_FILE):
            msg = f"Config file not found: {CONFIG_FILE}"
            if msg != LAST_ERROR:
                print(msg, file=sys.stderr)
                LAST_ERROR = msg
            return False
            
        mtime = os.path.getmtime(CONFIG_FILE)
        if mtime <= LAST_MTIME:
            return False
            
        with open(CONFIG_FILE, 'r') as f:
            COLOR_RULES = json.load(f)
            
        LAST_MTIME = mtime
        LAST_ERROR = "" # Clear error on success
        print(f"Loaded {len(COLOR_RULES)} rules from {CONFIG_FILE}")
        
        # Clear cache so new rules are applied
        global APPLIED_COLORS
        APPLIED_COLORS = {}
        
        return True
    except Exception as e:
        msg = f"Error loading config: {e}"
        if msg != LAST_ERROR:
            print(msg, file=sys.stderr)
            LAST_ERROR = msg
        return False

# Cache to prevent redundant IPC calls and infinite loops
# Map window_id -> (bg_color, text_color)
APPLIED_COLORS = {}

def apply_title_format(ipc, window, bg_color, text_color):
    global APPLIED_COLORS
    
    # Check cache
    if window.id in APPLIED_COLORS:
        last_bg, last_text = APPLIED_COLORS[window.id]
        if last_bg == bg_color and last_text == text_color:
            return

    # Check if it's XWayland to preserve the suffix
    suffix = ""
    shell = window.ipc_data.get('shell') if hasattr(window, 'ipc_data') else None
    if shell == "xwayland":
        suffix = " [XWayland]"
    
    # Construct Pango markup
    if bg_color or text_color:
        attrs = ""
        if bg_color:
            attrs += f" background='{bg_color}'"
        if text_color:
            attrs += f" foreground='{text_color}'"
        fmt = f"<span{attrs}> %title{suffix} </span>"
    else:
        fmt = f"%title{suffix}"
        
    # We need to escape double quotes for the sway command
    fmt_escaped = fmt.replace('"', '\\"')
    
    cmd = f"[con_id={window.id}] title_format \"{fmt_escaped}\""
    ipc.command(cmd)
    
    # Update cache
    APPLIED_COLORS[window.id] = (bg_color, text_color)

def get_colors_for_window(window):
    # Properties to check against
    props = {
        "app_id": window.app_id or "",
        "title": window.name or "",
        "class": window.window_class or "",
        "instance": window.window_instance or "",
        "role": window.window_role or "",
        "shell": window.ipc_data.get('shell') if hasattr(window, 'ipc_data') else ""
    }

    for rule in COLOR_RULES:
        is_match = True
        
        # 1. Check generic 'match' (any of title, app_id, class)
        if "match" in rule:
            key = rule["match"].lower()
            if not ((key in props["title"].lower()) or \
                    (key in props["app_id"].lower()) or \
                    (key in props["class"].lower())):
                is_match = False
        
        # 2. Check specific properties if defined in rule
        # If any specific property is defined, it MUST match
        for prop_name in ["app_id", "title", "class", "instance", "role", "shell"]:
            if prop_name in rule:
                # Case-insensitive substring match
                if rule[prop_name].lower() not in props[prop_name].lower():
                    is_match = False
                    break
        
        if is_match:
            return rule.get("bg_color"), rule.get("text_color")
            
    return None, None

def apply_to_all_windows(ipc):
    global APPLIED_COLORS
    # Clear cache on full re-apply to ensure we update if config changed
    # But we should be careful not to cause a loop if we are called from watcher
    # Actually, if config changed, we want to re-apply even if colors look same in cache?
    # No, if colors are same as last applied, we don't need to send command.
    # BUT if config changed, the mapping might be different for the same window.
    # So we should probably clear cache when config loads.
    
    tree = ipc.get_tree()
    for window in tree.leaves():
        matched_bg, matched_text = get_colors_for_window(window)
        apply_title_format(ipc, window, matched_bg, matched_text)

def on_window_event(ipc, event):
    try:
        window = event.container
        matched_bg, matched_text = get_colors_for_window(window)
        apply_title_format(ipc, window, matched_bg, matched_text)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)

def watch_config():
    # Create a separate connection for the watcher thread
    # This avoids thread-safety issues with the main connection
    watcher_ipc = None
    
    while True:
        time.sleep(1)
        if load_config():
            print("Config changed, reapplying to all windows...")
            try:
                if watcher_ipc is None:
                     watcher_ipc = i3ipc.Connection()
                apply_to_all_windows(watcher_ipc)
            except Exception as e:
                print(f"Error applying changes in watcher: {e}", file=sys.stderr)
                # Try to reconnect if connection failed
                try:
                    watcher_ipc = i3ipc.Connection()
                except:
                    pass

if __name__ == "__main__":
    # Initial load
    load_config()
    
    ipc = i3ipc.Connection()
    
    # Apply initially
    apply_to_all_windows(ipc)
    
    # Start watcher thread
    # We don't pass ipc to it anymore, it creates its own
    watcher = threading.Thread(target=watch_config, daemon=True)
    watcher.start()
    
    # Subscribe to events
    ipc.on("window::new", on_window_event)
    ipc.on("window::title", on_window_event)
    
    ipc.main()
