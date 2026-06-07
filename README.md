<h1>
    <p align="center">
waybar-vps
</p>
</h1>

<p align="center">
A simple <a href="https://github.com/Alexays/Waybar"><b>Waybar</b></a> module to monitor one or more VPS servers.
</p>
<p align="center">
<img width="80" height="33" alt="image" src="https://github.com/user-attachments/assets/88e7f2a6-e25a-4588-b48f-ac90265938ab" />
<img width="100" height="33" alt="image" src="https://github.com/user-attachments/assets/f884593d-d350-4798-9537-fe7820564c32" />
  <img width="89" height="33" alt="image" src="https://github.com/user-attachments/assets/15c3e140-dea8-461e-8f4d-67eeb978a73a" />
<img width="102" height="33" alt="image" src="https://github.com/user-attachments/assets/eb771e09-e937-431e-9102-07b762241990" />
</p>

Supports ping, HTTP endpoints, and TCP ports. Hover shows the
status of every configured server. Used in my <a href="https://github.com/bufferbloat/dotfiles"><b>dotfiles</b></a>.

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

<img width="80" height="33" alt="image" src="https://github.com/user-attachments/assets/88e7f2a6-e25a-4588-b48f-ac90265938ab" />
<img width="100" height="33" alt="image" src="https://github.com/user-attachments/assets/f884593d-d350-4798-9537-fe7820564c32" />


Example config:

```ini
DISPLAY_NAME=vps
TIMEOUT=3

SERVER=production|ping|203.0.113.10
```

### Multiple servers

With multiple servers, the default `count` style shows how many are online:

<img width="89" height="31" alt="image" src="https://github.com/user-attachments/assets/15c3e140-dea8-461e-8f4d-67eeb978a73a" />

Example config:

```ini
DISPLAY_NAME=vps
DISPLAY_STYLE=count
TIMEOUT=3

SERVER=production|ping|203.0.113.10
SERVER=api|http|https://example.com/health|200
SERVER=ssh|tcp|203.0.113.10|22
```

Use `DISPLAY_STYLE=circles` to show one colored circle per server:

<img width="102" height="33" alt="image" src="https://github.com/user-attachments/assets/eb771e09-e937-431e-9102-07b762241990" />


The circles follow the order of the `SERVER=` lines.

## Styling

The module returns `up`, `down`, and `error` classes. Example CSS is available
in `style.css`.

```css
#custom-vps.up {
  color: #a6e3a1;
}

#custom-vps.down {
  color: #f38ba8;
}

#custom-vps.error {
  color: #f9e2af;
}
```

## Requirements

- Bash
- jq
- curl
- A server lol


## Contributing

Issues and pull requests are welcome.

