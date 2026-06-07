# waybar-vps

A simple Waybar module to monitor one or more VPS servers.

It supports ping, HTTP endpoints, and TCP ports. Hovering the module shows the
status of every configured server.

## Installation

Clone the repository inside your Waybar scripts folder:

```bash
cd ~/.config/waybar/scripts
git clone https://github.com/bufferbloat/waybar-vps
cd waybar-vps
cp config.example config
```

Edit `config` and add your servers.

## Waybar configuration

Add the module to your Waybar config:

```jsonc
"custom/vps": {
  "exec": "~/.config/waybar/scripts/waybar-vps/waybar-vps.sh --status",
  "return-type": "json",
  "interval": 30,
  "signal": 8,
  "tooltip": true,
  "on-click": "pkill -RTMIN+8 waybar"
}
```

Add `"custom/vps"` to one of your module lists.

Left click refreshes all servers.

## Configuration

Each server is configured with one `SERVER=` line:

```ini
SERVER=name|check_type|target|option
```

The last option depends on the check type:

```ini
SERVER=production|ping|203.0.113.10
SERVER=api|http|https://example.com/health|200
SERVER=ssh|tcp|203.0.113.10|22
```

### One server

With one server, the module keeps the simple status display:

```text
vps: up
```

Example config:

```ini
DISPLAY_NAME=vps
TIMEOUT=3

SERVER=production|ping|203.0.113.10
```

### Multiple servers

With multiple servers, the default `count` style shows how many are online:

```text
vps: 2/3
```

```ini
DISPLAY_NAME=vps
DISPLAY_STYLE=count
TIMEOUT=3

SERVER=production|ping|203.0.113.10
SERVER=api|http|https://example.com/health|200
SERVER=ssh|tcp|203.0.113.10|22
```

Use `DISPLAY_STYLE=circles` to show one colored circle per server:

```text
vps: ● ● ●
```

The circles follow the order of the `SERVER=` lines.

## Styling

The status text and circles are colored by the script. `style.css` adds
spacing around the module.

The module also returns `up`, `down`, and `error` classes if you want to add
custom backgrounds, borders, or other state-based styling.

## Requirements

- Bash
- `jq`
- `ping` for ping checks
- `curl` for HTTP checks
- GNU `timeout` for TCP checks

## Contributing

Issues and pull requests are welcome.
