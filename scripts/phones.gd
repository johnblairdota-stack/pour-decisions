## Phones as controllers, the way couch party games on a TV do it.
##
## The game runs a tiny web server on the local network. Each player opens the
## address shown on screen on their phone (same Wi-Fi), and gets a controller
## page: a stick on the left and A / B / X / Y on the right. The page talks to
## the game over a WebSocket. The buttons a player is being asked to press
## pulse on their phone as well as on the TV.
##
##   http://<this computer's address>:8080   the controller page
##   ws://<this computer's address>:8081     controller input
##
## Messages from a phone (text): "hello <token>", "m <x> <y>", "d <A|B|X|Y>",
## "u <A|B|X|Y>". To a phone: "p <player number> <colour hex>",
## "c <button:verb:hold progress:urgent,...>", "j <role> <colour> <name|job>", "v <ms>",
## "full". The token lets a phone that drops out reconnect to the same chibi.
extends Node

const PORTS := [[8080, 8081], [8090, 8091], [8180, 8181], [18080, 18081]]
const VIRTUAL := ["virtualbox", "vmware", "vethernet", "hyper-v", "wsl", "docker", "loopback", "bluetooth", "tailscale", "zerotier", "hamachi", "vpn", "tap-", "tun"]
const MIN_TAP_MS := 90         # a tap counts as held at least this long
const PAGE := preload("res://scripts/controller_page.gd")
const UI := preload("res://scripts/ui.gd")

var game
var http := TCPServer.new()
var ws_server := TCPServer.new()
var _http_conns: Array = []     # [StreamPeerTCP, buffer, age]
var clients: Array = []         # {ws, token, player, last_cues}
var tokens := {}                # token -> player
var address := ""
var addresses: Array = []       # every LAN address, best first
var http_port := 8080
var ws_port := 8081
var running := false
var _cue_t := 0.0

func start(owner_game) -> void:
	game = owner_game
	# (if something else on the computer has the usual ports, try the next pair)
	for pair in PORTS:
		http = TCPServer.new()
		ws_server = TCPServer.new()
		var e1 := http.listen(pair[0])
		var e2 := ws_server.listen(pair[1])
		if e1 == OK and e2 == OK:
			http_port = pair[0]
			ws_port = pair[1]
			running = true
			break
		http.stop()
		ws_server.stop()
	addresses = _lan_addresses()
	address = addresses[0] if not addresses.is_empty() else ""
	if game.autotest:
		print("[phones] listening: %s (running %s, also %s)" % [url(), running, str(addresses.slice(1))])

func url() -> String:
	return "http://%s:%d" % [address, http_port] if address != "" else ""

## The other addresses this computer has, for when the first doesn't load.
func other_urls() -> Array:
	var out: Array = []
	for a in addresses.slice(1, 3):
		out.append("http://%s:%d" % [a, http_port])
	return out

## This computer's addresses on the local network, best guess first: the
## Wi-Fi or Ethernet adapter, not a virtual one (VirtualBox, Hyper-V, WSL,
## VPNs), which a phone on the Wi-Fi can't reach.
func _lan_addresses() -> Array:
	var scored: Array = []
	for itf in IP.get_local_interfaces():
		var nm: String = (String(itf.get("friendly", "")) + " " + String(itf.get("name", ""))).to_lower()
		var virtual := false
		for word in VIRTUAL:
			if nm.contains(word):
				virtual = true
		for a in itf.get("addresses", []):
			var ip := String(a)
			if ip.contains(":") or ip.begins_with("127.") or ip.begins_with("169.254."):
				continue
			var score := 0
			if ip.begins_with("192.168."):
				score += 30
			elif ip.begins_with("10."):
				score += 20
			elif ip.begins_with("172."):
				score += 10
			if nm.contains("wi-fi") or nm.contains("wifi") or nm.contains("wlan") or nm.contains("wireless"):
				score += 50
			elif nm.contains("ethernet") or nm.begins_with("eth") or nm.begins_with("en"):
				score += 40
			if virtual:
				score -= 100
			scored.append([score, ip])
	scored.sort_custom(func(x, y): return x[0] > y[0])
	var out: Array = []
	for e in scored:
		if not out.has(e[1]):
			out.append(e[1])
	return out

func _process(delta: float) -> void:
	if not running:
		return
	_serve_http(delta)
	_serve_ws()
	_release_taps()
	_cue_t -= delta
	if _cue_t <= 0.0:
		_cue_t = 0.1
		for c in clients:
			_send_cues(c)

# ------------------------------------------------------------------ the page

func _serve_http(delta: float) -> void:
	while http.is_connection_available():
		_http_conns.append([http.take_connection(), PackedByteArray(), 0.0])
	for hc in _http_conns:
		var conn: StreamPeerTCP = hc[0]
		hc[2] += delta
		conn.poll()
		if conn.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			hc[2] = 99.0
			continue
		var n := conn.get_available_bytes()
		if n > 0:
			var got: Array = conn.get_data(n)
			if got[0] == OK:
				hc[1].append_array(got[1])
		var text: String = (hc[1] as PackedByteArray).get_string_from_utf8()
		if text.contains("\r\n\r\n"):
			var first := text.get_slice("\r\n", 0)
			var path := first.get_slice(" ", 1)
			var body: PackedByteArray
			var status := "200 OK"
			var ctype := "text/html; charset=utf-8"
			if path == "/" or path.begins_with("/?") or path == "/index.html":
				body = PAGE.html(ws_port).to_utf8_buffer()
			elif path == "/manifest.json":
				# Add it to the home screen and it opens like an app: full
				# screen, sideways, no browser bars
				ctype = "application/manifest+json"
				body = PAGE.MANIFEST.to_utf8_buffer()
			elif path == "/icon.png":
				ctype = "image/png"
				body = _icon_png()
			else:
				status = "404 Not Found"
				ctype = "text/plain"
				body = "not found".to_utf8_buffer()
			var head := "HTTP/1.1 %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n" % [status, ctype, body.size()]
			conn.put_data(head.to_utf8_buffer())
			conn.put_data(body)
			hc[2] = 98.0
	for hc in _http_conns:
		if hc[2] > 5.0:
			(hc[0] as StreamPeerTCP).disconnect_from_host()
	_http_conns = _http_conns.filter(func(hc): return hc[2] <= 5.0)

var _icon_cache := PackedByteArray()

## The home-screen icon: a yellow hard hat on the night sky, drawn here so
## there's no file to ship.
func _icon_png() -> PackedByteArray:
	if not _icon_cache.is_empty():
		return _icon_cache
	var n := 192
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color("06060a"))
	var c := Vector2(n * 0.5, n * 0.56)
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5)
			var dome: bool = p.y < c.y and p.distance_to(c) < n * 0.34
			var brim: bool = absf(p.y - c.y) < n * 0.045 and absf(p.x - c.x) < n * 0.42
			if dome or brim:
				img.set_pixel(x, y, Color("ffc23d"))
			elif absf(p.y - (c.y + n * 0.2)) < n * 0.035 and absf(p.x - c.x) < n * 0.3:
				img.set_pixel(x, y, Color("27c4ac"))
	_icon_cache = img.save_png_to_buffer()
	return _icon_cache

# ------------------------------------------------------------------ controllers

func _serve_ws() -> void:
	while ws_server.is_connection_available():
		var ws := WebSocketPeer.new()
		ws.accept_stream(ws_server.take_connection())
		clients.append({"ws": ws, "token": "", "player": null, "last_cues": "", "downs": {}, "ups": {}, "held": {}})
	for c in clients:
		var ws: WebSocketPeer = c["ws"]
		ws.poll()
		var state := ws.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			while ws.get_available_packet_count() > 0:
				_on_message(c, ws.get_packet().get_string_from_utf8())
		elif state == WebSocketPeer.STATE_CLOSED:
			_release(c)
			c["dead"] = true
	clients = clients.filter(func(c): return not c.get("dead", false))

func _on_message(c: Dictionary, msg: String) -> void:
	if game._dbg:
		print("[phones] %s -> %s" % [msg, c["player"].char_name if c["player"] != null else "-"])
	var parts := msg.split(" ")
	if parts.is_empty():
		return
	match parts[0]:
		"hello":
			var token := parts[1] if parts.size() > 1 else str(randi())
			c["token"] = token
			var p = tokens.get(token)
			if p == null or not is_instance_valid(p):
				p = game.join_phone()
			if p == null:
				(c["ws"] as WebSocketPeer).send_text("full")
				return
			tokens[token] = p
			c["player"] = p
			p.ai = true
			p.remote_id = 1
			(c["ws"] as WebSocketPeer).send_text("p %d %s" % [p.index, p.tag_color.to_html(false)])
		"m":
			var p = c["player"]
			if game.pause_menu.visible:
				game.pause_menu.phone_y = parts[2].to_float() if parts.size() >= 3 else 0.0
				return
			if p != null and p.covering:
				_uncover(c, p)
			if p != null:
				p.idle_in = 0.0
			if p != null and parts.size() >= 3:
				p.ai_move = Vector2(parts[1].to_float(), parts[2].to_float()).limit_length(1.0)
		"d", "u":
			var p = c["player"]
			if parts.size() >= 2 and parts[1] == "MENU":
				# The phone's menu button pauses (and unpauses) the game
				if parts[0] == "d":
					game.pause_menu.toggle()
				return
			if game.pause_menu.visible:
				if parts[0] == "d" and parts.size() >= 2:
					game.pause_menu.phone_button(parts[1])
				return
			if parts.size() >= 2:
				var held: Dictionary = c["held"]
				if parts[0] == "d":
					held[parts[1]] = true
				else:
					held.erase(parts[1])
			if p != null and p.covering:
				_uncover(c, p)
			if p != null:
				p.idle_in = 0.0
			if p != null and parts.size() >= 2:
				var on: bool = parts[0] == "d"
				var b: String = parts[1]
				# A quick tap's down and up often arrive in the same frame
				# (phones bundle Wi-Fi packets), so the game would never see
				# it: a tapped button stays down for at least MIN_TAP_MS
				var now := Time.get_ticks_msec()
				var downs: Dictionary = c["downs"]
				var ups: Dictionary = c["ups"]
				if on:
					downs[b] = now
					ups.erase(b)
				elif now - int(downs.get(b, 0)) < MIN_TAP_MS:
					ups[b] = int(downs.get(b, 0)) + MIN_TAP_MS
					return
				_set_button(p, b, on)

## A covered phone player's back: their crewmate lets go, and whatever
## they're holding on the phone right now carries straight on.
func _uncover(c: Dictionary, p) -> void:
	p.uncover()
	for b in c["held"]:
		_set_button(p, b, true)

## Lets go of taps once they've been down long enough to count.
func _release_taps() -> void:
	var now := Time.get_ticks_msec()
	for c in clients:
		var ups: Dictionary = c["ups"]
		for b in ups.keys():
			if now >= int(ups[b]):
				ups.erase(b)
				if c["player"] != null and is_instance_valid(c["player"]):
					_set_button(c["player"], b, false)

func _set_button(p, b: String, on: bool) -> void:
	match b:
		"A": p.ai_action = on
		"B": p.ai_leave = on
		"X": p.ai_alt = on
		"Y": p.ai_slow = on

func _release(c: Dictionary) -> void:
	var p = c["player"]
	if p != null and is_instance_valid(p):
		p.ai_move = Vector2.ZERO
		p.ai_action = false
		p.ai_alt = false
		p.ai_slow = false
		p.ai_leave = false

## Tell the phone which buttons are being asked for, so they pulse there too.
func _send_cues(c: Dictionary) -> void:
	var p = c["player"]
	if p == null or not is_instance_valid(p):
		return
	var list := []
	for cu in p.cues:
		if cu[0] in ["A", "B", "X", "Y"]:
			# button:verb:hold progress (-1 none):urgent
			var prog: float = cu[2]
			list.append("%s:%s:%s:%d:%d" % [cu[0], str(cu[1]).replace(" ", "_").replace(":", ""), ("%.2f" % snappedf(prog, 0.05)) if prog >= 0.0 else "-1", 1 if (cu[3] or cu[5]) else 0, 1 if (p.is_gold(cu) and not cu[5]) else 0])
	var text := "c " + ",".join(list)
	if text != c["last_cues"]:
		c["last_cues"] = text
		(c["ws"] as WebSocketPeer).send_text(text)
	# Who you are and your job, in the job's colour with its icon
	var col: Color = UI.ROLE.get(p.role, Color.WHITE)
	var job := "j %s %s %s" % [p.role, col.to_html(false), (p.char_name + "|" + UI.ROLE_NAME.get(p.role, p.role)).replace(" ", "_")]
	if job != c.get("last_job", ""):
		c["last_job"] = job
		(c["ws"] as WebSocketPeer).send_text(job)

## Control of a chibi moved to another one (a person swapped jobs).
func retarget(old_p, new_p) -> void:
	for token in tokens:
		if tokens[token] == old_p:
			tokens[token] = new_p
	for c in clients:
		if c["player"] == old_p:
			c["player"] = new_p
			c["last_cues"] = ""
			(c["ws"] as WebSocketPeer).send_text("p %d %s" % [new_p.index, new_p.tag_color.to_html(false)])

## A buzz in this person's hand (phones that support it): ms, or a pattern "40,30,40".
func vibrate(p, pattern: String) -> void:
	for c in clients:
		if c["player"] == p:
			(c["ws"] as WebSocketPeer).send_text("v " + pattern)

func connected_count() -> int:
	var n := 0
	for c in clients:
		if c["player"] != null:
			n += 1
	return n
