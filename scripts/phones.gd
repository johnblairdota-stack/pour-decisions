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
## Messages from a phone (text): "hello <token>", "m <x> <y>", "d <A|B|X|Y|MENU>",
## "u <A|B|X|Y>", and for picking jobs "pick <job>", "lock", "unlock",
## "char <1|-1>" (in the lobby) and "swap <job>" (on site, to a job a bot's
## doing), and for signing the top slab "ink <x> <y>" (0..1 across your
## square), "inkup", "inkclr" and "inkok". To a phone: "p <player number> <colour hex>",
## "c <button:verb:hold progress:urgent:gold,...>", "v <ms pattern>", "full",
## and "J <json>" for the rest: {t: state} lobby / site / play / pause,
## {t: roster} who's on each job, {t: state, s: sign, left} signing the slab, {t: card} your job ticket, {t: now} the
## ticket's live step, {t: gauge} the pump gauge (pump operator), {t: nudge}
## how long the game's been waiting on you, {t: toast} a short note.
## The token lets a phone that drops out reconnect to the same chibi.
extends Node

const Wallet := preload("res://scripts/wallet.gd")
const CashArt := preload("res://scripts/cash_art.gd")

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
			elif path.begins_with("/font/") and FONTS.has(path.substr(6)):
				# The Site Kit's Barlow, the same as the TV's
				ctype = "font/ttf"
				body = _font_bytes(path.substr(6))
			else:
				status = "404 Not Found"
				ctype = "text/plain"
				body = "not found".to_utf8_buffer()
			var cache := "max-age=86400" if ctype == "font/ttf" else "no-store"
			var head := "HTTP/1.1 %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nCache-Control: %s\r\nConnection: close\r\n\r\n" % [status, ctype, body.size(), cache]
			conn.put_data(head.to_utf8_buffer())
			conn.put_data(body)
			hc[2] = 98.0
	for hc in _http_conns:
		if hc[2] > 5.0:
			(hc[0] as StreamPeerTCP).disconnect_from_host()
	_http_conns = _http_conns.filter(func(hc): return hc[2] <= 5.0)

var _icon_cache := PackedByteArray()
const FONTS := {"head.ttf": "res://fonts/BarlowCondensed-ExtraBold.ttf", "body.ttf": "res://fonts/Barlow-SemiBold.ttf"}
var _font_cache := {}

func _font_bytes(name: String) -> PackedByteArray:
	if not _font_cache.has(name):
		_font_cache[name] = FileAccess.get_file_as_bytes(FONTS[name]) if FileAccess.file_exists(FONTS[name]) else PackedByteArray()
	return _font_cache[name]

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
		"pick", "lock", "unlock", "char", "swap":
			_on_pick(c, parts)
			return
		"buy":
			# The wallet's shop: a ute, or kit for the ute they drive
			var bp = c["player"]
			if bp != null and parts.size() >= 2:
				var why: String = Wallet.buy(bp.char_id, parts[1])
				if why == "":
					var what: Dictionary = Wallet.ute(parts[1]) if not Wallet.ute(parts[1]).is_empty() else Wallet.item(parts[1])
					game.hud.toast("%s bought a %s" % [bp.char_name, String(what.get("name", "")).to_lower()], 2.0)
					game.sfx.hit("ding")
				(c["ws"] as WebSocketPeer).send_text("J " + JSON.stringify({"t": "bought", "id": parts[1], "why": why}))
			return
		"wallet":
			# (the wallet's open: the chibi stands still meanwhile)
			if c["player"] != null:
				c["player"].set_meta("wallet_open", parts.size() >= 2 and parts[1] == "1")
			return
		"ink":
			if parts.size() >= 3 and c["player"] != null:
				game.ink_point(c["player"], Vector2(parts[1].to_float(), parts[2].to_float()))
		"inkup":
			game.ink_up(c["player"])
		"inkclr":
			game.ink_clear(c["player"])
		"inkok":
			game.ink_done(c["player"])
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
					game.pause_menu.toggle(p.index if p != null else -1)
				return
			if game.pause_menu.visible:
				if parts[0] == "d" and parts.size() >= 2:
					game.pause_menu.phone_button(parts[1], p.index if p != null else -1)
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
	# The toolbox talk's on the TV: the phone's A starts the pour too
	var bh: float = game.brief_hold() if game.has_method("brief_hold") else -1.0
	if bh >= 0.0 and p.cues.is_empty():
		list.append("A:start_the_pour:%.2f:1:1:0" % snappedf(bh, 0.05))
	for cu in p.cues:
		if cu[0] in ["A", "B", "X", "Y"]:
			var prog: float = cu[2]
			# button:verb:hold progress (-1 none):urgent:gold:alarm
			# (gold is how bright, 0..1: the assist fades as the person gets good)
			var zv: Vector2 = cu[4] if cu.size() > 4 else Vector2(-1, -1)
			var banded: bool = zv.x >= 0.0 and prog >= zv.x and prog <= zv.y
			var gl: float = 0.0 if cu[5] or not p.is_gold(cu) else (1.0 if banded else p.gold_amount(cu))
			list.append("%s:%s:%s:%d:%s:%d" % [cu[0], str(cu[1]).replace(" ", "_").replace(":", "").replace(",", ""), ("%.2f" % snappedf(prog, 0.05)) if prog >= 0.0 else "-1", 1 if (cu[3] or cu[5]) else 0, "%.1f" % gl, 1 if cu[5] else 0])
	var text := "c " + ",".join(list)
	if text != c["last_cues"]:
		c["last_cues"] = text
		(c["ws"] as WebSocketPeer).send_text(text)
	_send_state(c)

# ------------------------------------------------------------------ job ticket, lobby and swaps

func _json(c: Dictionary, key: String, d: Dictionary) -> void:
	var text := JSON.stringify(d)
	var sent: Dictionary = c.get("sent", {})
	if sent.get(key, "") == text:
		return
	sent[key] = text
	c["sent"] = sent
	(c["ws"] as WebSocketPeer).send_text("J " + text)

## Which screen the phone shows: the lobby (picking jobs), the site pick,
## the game, or the pause menu.
func screen() -> String:
	if game.pause_menu != null and game.pause_menu.visible:
		return "pause"
	if game.phase == "roles":
		return "lobby"
	if game.phase == "select":
		return "site"
	if game.phase == "sign":
		return "sign"
	return "play"

## Everything the page shows besides the buttons, each sent when it changes.
func _send_state(c: Dictionary) -> void:
	var p = c["player"]
	if p == null or not is_instance_valid(p):
		return
	var scr := screen()
	var sel = game.selector if is_instance_valid(game.selector) else null
	var st := {"t": "state", "s": scr, "p": p.index, "pc": p.tag_color.to_html(false), "name": p.char_name}
	if sel != null and scr == "lobby":
		st["locked"] = bool(sel._ready_p.get(p.index, false))
		st["count"] = int(ceil(sel._count_t)) if sel._count_t > 0.0 else -1
	if scr == "sign":
		st["left"] = int(ceil(game.ink_left()))
		st["done"] = bool(game._ink_done.get(p, false))
	_json(c, "state", st)
	_json(c, "roster", roster())
	_json(c, "card", card(p.role))
	var climb_day: bool = game.climb != null and game.climb.active
	var now := {"t": "now", "i": -1, "verb": "", "btn": "", "climb": climb_day,
		"go": game.where_to(p) if game.has_method("where_to") and scr == "play" else "",
		"brief": game.brief_hold() if game.has_method("brief_hold") and scr == "play" else -1.0}
	if not p.cues.is_empty():
		var cu: Array = p.cues[0]
		now["btn"] = cu[0]
		now["verb"] = str(cu[1])
		if not climb_day:
			now["i"] = UI.step_for(p.role, cu[0], str(cu[1]))
	_json(c, "now", now)
	if p.role == "pump" and game.line != null and scr == "play":
		var ln = game.line
		_json(c, "gauge", {"t": "gauge", "bar": int(ln.pressure / 5.0) * 5, "spike": bool(ln.spike_on), "warn": bool(ln.spike_warn), "tripped": bool(ln.tripped)})
	# The dogman's calls round the phone's stick, each the way the stick
	# pushes to make it (they turn with the TV's camera), the held one lit
	var dog := {"t": "dog", "on": false}
	var cl = game.climb
	if cl != null and cl.active and cl.stage == "guide" and p.busy == "dogman" and scr == "play":
		var calls := []
		var dirs: Dictionary = cl.call_dirs()
		for k in dirs:
			var s: Vector2 = cl.stick_of(dirs[k])
			calls.append([k, int(round(rad_to_deg(atan2(s.y, s.x)) / 5.0)) * 5])
		dog = {"t": "dog", "on": true, "c": calls, "lit": cl._call}
	_json(c, "dog", dog)
	_json(c, "nudge", {"t": "nudge", "lvl": int(game.nudge_level(p)) if game.has_method("nudge_level") else 0})
	_json(c, "wallet", wallet(p))
	if not c.has("shop_sent"):
		c["shop_sent"] = true
		(c["ws"] as WebSocketPeer).send_text("J " + JSON.stringify({"t": "shop", "utes": Wallet.UTES, "kit": Wallet.KIT}))

## What's in this person's wallet: {t, name, cash, pour (this slab), banked,
## utes, ute (the one they drive), kit (on it)}.
func wallet(p) -> Dictionary:
	var w: Dictionary = Wallet.of(p.char_id)
	var pour := 0
	if game.score != null:
		pour = int(game.score.wallet_pour.get(p.char_id, 0))
	return {"t": "wallet", "name": p.char_name, "cash": int(w.get("cash", 0)), "pour": pour, "banked": int(w.get("banked", 0)),
		"utes": w.get("utes", []), "ute": w.get("ute", ""), "kit": Wallet.kit_on(p.char_id),
		# (the wallet's art, fatter the more's in it: thin at the start, full at $500,000)
		"purse": CashArt.wallet_svg(clampf(log(float(w.get("cash", 0)) + 1.0) / log(500001.0), 0.0, 1.0))}

## Who's on every job: {t, r: [{id, name, col, line, p (0: a bot), pc, who, lock}]}.
func roster() -> Dictionary:
	var out: Array = []
	var sel = game.selector if is_instance_valid(game.selector) else null
	for role in game.crew.ROLES:
		var q = game.crew.crew[role]
		out.append({"id": role, "name": UI.ROLE_NAME[role], "col": UI.ROLE[role].to_html(false), "line": UI.ROLE_SHORT[role], "ask": UI.ROLE_ASK[role],
			"p": 0 if q.bot else q.index, "pc": q.tag_color.to_html(false), "who": q.char_name,
			"lock": (not q.bot) and sel != null and bool(sel._ready_p.get(q.index, false))})
	return {"t": "roster", "r": out}

## A job's ticket: its goal, its steps, what to watch for, climb days.
func card(role: String) -> Dictionary:
	var jc: Dictionary = UI.JOB_CARD.get(role, {})
	return {"t": "card", "role": role, "name": UI.ROLE_NAME.get(role, role), "col": UI.ROLE.get(role, Color.WHITE).to_html(false),
		"goal": jc.get("goal", ""), "steps": UI.how(role), "watch": jc.get("watch", ""),
		"climb": UI.ROLE_CLIMB.get(role, ""), "climbsteps": UI.how(role, "climb")}

func _toast(c: Dictionary, msg: String) -> void:
	(c["ws"] as WebSocketPeer).send_text("J " + JSON.stringify({"t": "toast", "msg": msg}))

## The phone's own job picking: in the lobby, tap a job then hold to lock in;
## on site, swap to a job a bot's doing.
func _on_pick(c: Dictionary, parts: PackedStringArray) -> void:
	var p = c["player"]
	if p == null or not is_instance_valid(p):
		return
	var crew = game.crew
	var sel = game.selector if is_instance_valid(game.selector) else null
	var role := parts[1] if parts.size() > 1 else ""
	match parts[0]:
		"pick":
			if sel == null or screen() != "lobby" or not crew.crew.has(role):
				return
			if bool(sel._ready_p.get(p.index, false)):
				return
			if not crew.crew[role].bot and crew.crew[role] != p:
				_toast(c, "P%d has that job" % crew.crew[role].index)
				return
			crew.assign(p.index, role)
			game.sfx.hit("tink")
		"lock", "unlock":
			if sel != null and screen() == "lobby":
				sel.set_ready(p.index, parts[0] == "lock")
		"char":
			if sel != null and screen() == "lobby" and not bool(sel._ready_p.get(p.index, false)):
				crew.cycle_char(p.index, 1 if role != "-1" else -1)
				game.sfx.hit("tink")
		"swap":
			if screen() != "play" or not crew.crew.has(role):
				return
			if not crew.crew[role].bot:
				_toast(c, "%s's taken" % UI.ROLE_NAME[role])
				return
			var me: int = p.index
			if crew.assign(me, role):
				var q = crew.human(me)
				game.hud.toast("P%d is on the %s job" % [me, UI.ROLE_NAME[role].to_lower()], 1.6)
				if q != null:
					vibrate(q, UI.BUZZ["done"])

## Control of a chibi moved to another one (a person swapped jobs).
func retarget(old_p, new_p) -> void:
	for token in tokens:
		if tokens[token] == old_p:
			tokens[token] = new_p
	for c in clients:
		if c["player"] == old_p:
			c["player"] = new_p
			c["last_cues"] = ""
			c["sent"] = {}
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
