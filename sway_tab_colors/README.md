# Sway Tab Colors

A dynamic Python script for the [Sway](https://swaywm.org/) window manager that colors window title bars based on matching rules (app ID, title, etc.). It uses Sway's `title_format` with Pango markup to apply custom background and text colors.

## Features

*   **Dynamic Coloring**: Automatically updates window colors when new windows open or titles change.
*   **Hot Reloading**: Watches the configuration file for changes and instantly reapplies rules to all open windows without restarting the script or Sway.
*   **Flexible Matching**: Match windows by `app_id`, window `title`, `class`, or a generic substring search.
*   **XWayland Support**: Preserves the `[XWayland]` suffix for X11 applications.

## Requirements

*   Python 3
*   `i3ipc` library

```bash
pip install i3ipc
```

## Configuration

The script looks for a JSON configuration file at a standard XDG configuration location.
By default, it uses:
`$XDG_CONFIG_HOME/sway/tab_colors.json`
or, if `XDG_CONFIG_HOME` is not set:
`~/.config/sway/tab_colors.json`

### Config Format

The configuration is a JSON list of rule objects. The script processes rules in order; the first match determines the colors.

#### Rule Properties
*   **Matching Keys** (at least one required):
    *   `app_id`: Exact (case-insensitive) match for the Wayland app ID.
    *   `class`: Exact (case-insensitive) match for the X11 window class.
    *   `title`: Exact (case-insensitive) match for the window title.
    *   `match`: A generic case-insensitive substring search across title, app ID, and class.
*   **Color Properties**:
    *   `text_color`: Color for the title text (e.g., "red", "#ff0000").
    *   `bg_color`: Color for the text background. **Note:** This highlights the text background, not the entire title bar background (which is controlled by Sway client colors).

### Example `tab_colors.json`

```json
[
    {
        "app_id": "firefox",
        "text_color": "orange"
    },
    {
        "app_id": "org.gnome.Terminal",
        "text_color": "#00ff00",
        "bg_color": "#000000"
    },
    {
        "match": "slack",
        "text_color": "white",
        "bg_color": "#4A154B"
    },
    {
        "match": "production",
        "text_color": "red",
        "bg_color": "yellow"
    }
]
```

## Installation & Usage

1.  Clone the repository.
2.  Install the dependency: `pip install i3ipc`.
3.  Create your config file at `$XDG_CONFIG_HOME/sway/tab_colors.json` (or `~/.config/sway/tab_colors.json` if `XDG_CONFIG_HOME` is not set).
4.  Make the script executable:
    ```bash
    chmod +x sway_tab_colors.py
    ```
5.  Run the script manually to test:
    ```bash
    ./sway_tab_colors.py
    ```
6.  To run it automatically with Sway, add this to your Sway config file (`~/.config/sway/config`):
    ```sway
    exec /path/to/sway_tab_colors/sway_tab_colors.py
    ```

## Troubleshooting

*   **Colors not showing?** Check if the script is running (`pgrep -f sway_tab_colors`). Ensure your config exists at `$XDG_CONFIG_HOME/sway/tab_colors.json` (or `~/.config/sway/tab_colors.json` if `XDG_CONFIG_HOME` is not set).
*   **Errors?** Run the script manually in a terminal to see output/error logs.
