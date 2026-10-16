## The phone controller page served by phones.gd: a stick and A / B / X / Y,
## in landscape, with the buttons the game is asking for pulsing.
extends RefCounted

const MANIFEST := '{"name": "Pour Decisions controller", "short_name": "Pour Decisions", "start_url": "/", "display": "fullscreen", "orientation": "landscape", "background_color": "#06060a", "theme_color": "#06060a", "icons": [{"src": "/icon.png", "sizes": "192x192", "type": "image/png"}]}'

static func html(ws_port: int) -> String:
	return PAGE.replace("__WS_PORT__", str(ws_port))

const PAGE := """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no,viewport-fit=cover">
<meta name="theme-color" content="#06060a">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="apple-mobile-web-app-title" content="Pour Decisions">
<link rel="manifest" href="/manifest.json">
<link rel="apple-touch-icon" href="/icon.png">
<title>Pour Decisions controller</title>
<style>
:root{--bg:#06060a;--ink:#14121c;--ring:rgba(255,120,160,.28);--txt:#f4f2ff;--muted:#8c87a3}
*{box-sizing:border-box;-webkit-tap-highlight-color:transparent;user-select:none;-webkit-user-select:none;touch-action:none}
html,body{margin:0;height:100%;background:var(--bg);color:var(--txt);font-family:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;overflow:hidden}
body{background:radial-gradient(60% 80% at 50% 0%,rgba(150,20,60,.22),transparent 70%),radial-gradient(50% 60% at 85% 70%,rgba(70,40,160,.18),transparent 70%),var(--bg)}
#pad{position:fixed;inset:0;display:grid;grid-template-columns:1fr 1fr}
#left,#right{position:relative}
#fx{position:fixed;inset:0;width:100%;height:100%;pointer-events:none;z-index:5}
#flash{position:fixed;inset:0;pointer-events:none;opacity:0;z-index:4}
#flash.go{animation:flash .32s ease-out}
@keyframes flash{0%{opacity:1}100%{opacity:0}}
/* stick */
#base{position:absolute;width:44vmin;height:44vmin;border-radius:50%;border:1.5px solid var(--ring);left:50%;top:55%;transform:translate(-50%,-50%);transition:border-color .2s,box-shadow .2s;background:radial-gradient(circle,rgba(255,255,255,.035),transparent 70%)}
#base.on{border-color:rgba(255,255,255,.55);box-shadow:0 0 0 1.5vmin rgba(255,255,255,.04),inset 0 0 6vmin rgba(160,140,255,.18)}
#wedge{position:absolute;inset:-1px;border-radius:50%;opacity:0;background:conic-gradient(from -30deg,rgba(190,170,255,.55),transparent 60deg,transparent 360deg);-webkit-mask:radial-gradient(farthest-side,transparent 62%,#000 64%);mask:radial-gradient(farthest-side,transparent 62%,#000 64%)}
#knob{position:absolute;width:19vmin;height:19vmin;border-radius:50%;background:radial-gradient(circle at 40% 35%,#ffffff,#e4dcff 55%,#cfc4f5);box-shadow:0 0 0 4px rgba(255,255,255,.9),0 8px 24px rgba(0,0,0,.6);left:50%;top:50%;transform:translate(-50%,-50%);transition:width .12s,height .12s,box-shadow .12s}
#base.on #knob{width:21vmin;height:21vmin;box-shadow:0 0 0 4px #fff,0 0 5vmin rgba(190,170,255,.7),0 10px 26px rgba(0,0,0,.6)}
/* buttons */
.btn{position:absolute;border-radius:50%;--p:0;--s:1;--y:0px}
.face{position:absolute;inset:0;border-radius:50%;display:flex;align-items:center;justify-content:center;font-weight:900;color:var(--ink);background:var(--bg-b);box-shadow:inset 0 -6px 12px rgba(0,0,0,.25),inset 0 6px 10px rgba(255,255,255,.35),0 1.6vmin 0 var(--rim),0 2.6vmin 22px rgba(0,0,0,.55);transform:translateY(var(--y)) scale(var(--s));transition:transform .22s cubic-bezier(.3,1.8,.5,1),box-shadow .12s,filter .12s}
.face span{font-size:9vmin;line-height:1;transition:transform .2s cubic-bezier(.3,2,.5,1)}
.btn.down .face{--s:.88;--y:1.4vmin;transition:transform .05s ease-out,box-shadow .05s,filter .05s;filter:brightness(1.25) saturate(1.2);box-shadow:inset 0 -2px 6px rgba(0,0,0,.25),inset 0 4px 14px rgba(255,255,255,.55),0 .2vmin 0 var(--rim),0 0 6vmin var(--glow)}
.btn.down .face span{transform:scale(1.18)}
.btn.boing .face{animation:boing .38s cubic-bezier(.3,1.6,.5,1)}
@keyframes boing{0%{transform:translateY(1.4vmin) scale(.88)}45%{transform:translateY(-.6vmin) scale(1.08)}100%{transform:translateY(0) scale(1)}}
.ring{position:absolute;inset:-2.4vmin;border-radius:50%;opacity:0;transition:opacity .15s;background:conic-gradient(var(--hi) calc(var(--p) * 1turn),rgba(255,255,255,.1) 0);-webkit-mask:radial-gradient(farthest-side,transparent calc(100% - 1.3vmin),#000 calc(100% - 1.2vmin));mask:radial-gradient(farthest-side,transparent calc(100% - 1.3vmin),#000 calc(100% - 1.2vmin))}
.btn.hold .ring{opacity:1}
.ripple{position:absolute;left:50%;top:50%;width:100%;height:100%;border-radius:50%;border:1vmin solid var(--hi);transform:translate(-50%,-50%) scale(1);opacity:.9;pointer-events:none;animation:ripple .5s ease-out forwards}
@keyframes ripple{to{transform:translate(-50%,-50%) scale(2.1);opacity:0;border-width:.2vmin}}
.verb{position:absolute;left:50%;top:100%;margin-top:3vmin;padding:.6vmin 2vmin;border-radius:3vmin;background:rgba(10,10,18,.8);border:1.5px solid var(--hi);font-size:3.4vmin;font-weight:800;color:var(--txt);white-space:nowrap;opacity:0;transform:translate(-50%,-1.5vmin) scale(.8);transition:opacity .15s,transform .2s cubic-bezier(.3,1.8,.5,1);text-shadow:0 2px 6px #000}
.btn.cue .verb{opacity:1;transform:translate(-50%,0) scale(1)}
.btn.cue .face{animation:pulse .9s ease-in-out infinite}
.btn.cue.urgent .face{animation:pulse .45s ease-in-out infinite,shake .45s linear infinite}
.btn.cue.urgent .verb{background:rgba(120,10,20,.9)}
#pad .btn.down .face{animation:none}
#pad .btn.boing .face{animation:boing .38s cubic-bezier(.3,1.6,.5,1)}
@keyframes pulse{0%,100%{box-shadow:inset 0 -6px 12px rgba(0,0,0,.25),inset 0 6px 10px rgba(255,255,255,.35),0 1.6vmin 0 var(--rim),0 0 0 0 var(--glow)}50%{box-shadow:inset 0 -6px 12px rgba(0,0,0,.25),inset 0 6px 10px rgba(255,255,255,.35),0 1.6vmin 0 var(--rim),0 0 0 3.4vmin var(--glow)}}
@keyframes shake{0%,100%{transform:rotate(0)}25%{transform:rotate(-5deg)}75%{transform:rotate(5deg)}}
#pad .btn.gold .face{animation:goldpulse .55s ease-in-out infinite;filter:brightness(1.12) saturate(1.15)}
#pad .btn.gold.down .face{animation:none;box-shadow:inset 0 -2px 6px rgba(0,0,0,.25),inset 0 4px 14px rgba(255,255,255,.55),0 .2vmin 0 var(--rim),0 0 0 1.2vmin #ffd23f,0 0 8vmin rgba(255,210,63,.9)}
#pad .btn.gold .verb{border-color:#ffd23f;color:#ffd23f;background:rgba(40,30,0,.88)}
#pad .btn.gold .face span{color:#3a2a00}
@keyframes goldpulse{0%,100%{transform:scale(1.03);box-shadow:inset 0 -6px 12px rgba(0,0,0,.25),inset 0 6px 10px rgba(255,255,255,.45),0 1.6vmin 0 var(--rim),0 0 0 1vmin #ffd23f,0 0 5vmin rgba(255,210,63,.6)}50%{transform:scale(1.11);box-shadow:inset 0 -6px 12px rgba(0,0,0,.25),inset 0 6px 10px rgba(255,255,255,.45),0 1.6vmin 0 var(--rim),0 0 0 1.6vmin #ffe680,0 0 9vmin rgba(255,210,63,.95)}}
#Y{width:18vmin;height:18vmin;left:42%;top:14%;--bg-b:radial-gradient(circle at 40% 30%,#ffe27a,#f5a524);--rim:#a8650e;--hi:#ffd23f;--glow:rgba(255,190,60,.45)}
#B{width:18vmin;height:18vmin;left:70%;top:8%;--bg-b:radial-gradient(circle at 40% 30%,#ff8f7a,#e5383b);--rim:#8e1c22;--hi:#ff6a5f;--glow:rgba(255,90,95,.45)}
#X{width:18vmin;height:18vmin;left:26%;top:46%;--bg-b:radial-gradient(circle at 40% 30%,#c4a6ff,#8a5cf6);--rim:#4b2aa3;--hi:#b18cff;--glow:rgba(155,107,255,.48)}
#A{width:26vmin;height:26vmin;left:57%;top:38%;--bg-b:radial-gradient(circle at 40% 30%,#8ff5e4,#27c4ac);--rim:#137a6a;--hi:#5ff0d6;--glow:rgba(63,224,197,.48)}
#A .face span{font-size:12vmin}
#top{position:fixed;left:27%;top:3vmin;transform:translateX(-50%);display:flex;flex-direction:column;align-items:center;gap:1.5vmin;z-index:6;pointer-events:none}
#badge{width:12vmin;height:12vmin;border-radius:50%;border:1.5px solid rgba(255,255,255,.25);display:flex;align-items:center;justify-content:center;font-weight:900;font-size:4.6vmin;background:#1b1826;transition:transform .3s cubic-bezier(.3,1.8,.5,1)}
#badge.hi{transform:scale(1.25)}
#status{font-size:3vmin;color:var(--muted)}
#job{display:none;align-items:center;gap:1.6vmin;padding:1vmin 2.6vmin 1vmin 1.4vmin;border-radius:4vmin;border:2px solid currentColor;background:rgba(10,14,24,.85);font-size:4vmin;font-weight:800}
#jicon{width:6.5vmin;height:6.5vmin}
#rotate,#gate{position:fixed;inset:0;background:var(--bg);display:none;align-items:center;justify-content:center;flex-direction:column;gap:3vmin;text-align:center;padding:6vmin;font-size:5vmin;z-index:10}
#gate{display:flex;cursor:pointer}
#gate b{font-size:8vmin;color:#ffc23d}
#ios{display:none;max-width:80vmin;font-size:3.6vmin;color:#c9c4e0;line-height:1.4;border:1.5px solid rgba(255,255,255,.18);border-radius:3vmin;padding:2.4vmin 3vmin;background:rgba(255,255,255,.04)}
#ios b{font-size:3.6vmin;color:#ffc23d}
#fs{position:fixed;right:3vmin;top:3vmin;width:9vmin;height:9vmin;border-radius:2.4vmin;border:1.5px solid rgba(255,255,255,.25);background:rgba(20,18,30,.7);color:#f4f2ff;display:none;align-items:center;justify-content:center;z-index:7}
#fs svg{width:5vmin;height:5vmin}
#menu{position:fixed;left:3vmin;top:3vmin;height:9vmin;padding:0 2.6vmin;border-radius:2.4vmin;border:1.5px solid rgba(255,255,255,.25);background:rgba(20,18,30,.7);color:#f4f2ff;display:flex;align-items:center;gap:1.4vmin;font-size:3.4vmin;font-weight:700;z-index:7}
#menu i{display:block;width:4.4vmin;height:.6vmin;background:currentColor;border-radius:1vmin;box-shadow:0 1.4vmin 0 currentColor,0 -1.4vmin 0 currentColor}
#menu.down{transform:scale(.92);background:rgba(60,56,80,.9)}
#Y .verb{top:50%;left:auto;right:100%;margin:0 2.4vmin 0 0;transform:translate(0,-50%) scale(.8)}
#Y.cue .verb{transform:translate(0,-50%) scale(1)}
@media (orientation:portrait){#rotate{display:flex}}
</style>
</head>
<body>
<canvas id="fx"></canvas><div id="flash"></div>
<div id="pad">
  <div id="left"><div id="base"><div id="wedge"></div><div id="knob"></div></div></div>
  <div id="right">
    <div class="btn" id="Y"><div class="ring"></div><div class="face"><span>Y</span></div><div class="verb"></div></div>
    <div class="btn" id="B"><div class="ring"></div><div class="face"><span>B</span></div><div class="verb"></div></div>
    <div class="btn" id="X"><div class="ring"></div><div class="face"><span>X</span></div><div class="verb"></div></div>
    <div class="btn" id="A"><div class="ring"></div><div class="face"><span>A</span></div><div class="verb"></div></div>
  </div>
</div>
<div id="top"><div id="badge">··</div><div id="job"><svg id="jicon" viewBox="0 0 128 128"></svg><span id="jname"></span></div><div id="status">connecting…</div></div>
<div id="rotate">Turn your phone sideways<br><small style="color:#8c87a3">the controller works in landscape</small></div>
<div id="gate"><b>POUR DECISIONS</b>Tap to join the crew<div id="ios"><b>Full screen on iPhone:</b> tap the Share button, then <b>Add to Home Screen</b>. Open Pour Decisions from your home screen and it fills the whole screen, like an app.</div></div>
<div id="menu"><i></i>Pause</div>
<div id="fs" title="Full screen"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"><path d="M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5"/></svg></div>
<script>
const PORT = __WS_PORT__;
// The job icons, the same drawings as on the TV
const S = 'stroke="currentColor" stroke-linecap="round" fill="none"';
const ICONS = {
  boom: '<path d="M18 110 L52 36 L108 52" stroke-width="16" ' + S + '/><path d="M108 52 L108 92" stroke-width="9" ' + S + '/><circle cx="52" cy="36" r="11" fill="currentColor"/><rect x="6" y="106" width="32" height="12" rx="3" fill="currentColor"/>',
  line: '<circle cx="64" cy="64" r="32" stroke-width="18" ' + S + '/><rect x="50" y="10" width="28" height="20" rx="3" fill="currentColor"/><rect x="50" y="98" width="28" height="20" rx="3" fill="currentColor"/>',
  pump: '<rect x="8" y="48" width="32" height="36" rx="5" fill="currentColor"/><ellipse cx="78" cy="58" rx="38" ry="24" fill="currentColor"/><rect x="10" y="79" width="112" height="10" rx="2" fill="currentColor"/><circle cx="26" cy="98" r="10" fill="currentColor"/><circle cx="74" cy="98" r="10" fill="currentColor"/><circle cx="100" cy="98" r="10" fill="currentColor"/>',
  poker: '<path d="M64 10 L64 100" stroke-width="14" ' + S + '/><rect x="54" y="96" width="20" height="24" rx="4" fill="currentColor"/><path d="M40 80 Q30 92 40 104 M26 74 Q12 92 26 110 M88 80 Q98 92 88 104 M102 74 Q116 92 102 110" stroke-width="7" ' + S + '/>',
  hose: '<path d="M22 12 C26 40 50 50 66 58 C80 66 88 80 88 96" stroke-width="18" ' + S + '/><rect x="77" y="96" width="24" height="16" rx="3" fill="currentColor"/><circle cx="80" cy="122" r="4.5" fill="currentColor"/><circle cx="98" cy="120" r="4.5" fill="currentColor"/>',
  screed: '<rect x="6" y="69" width="116" height="14" rx="3" fill="currentColor"/><path d="M36 70 L30 34 M92 70 L98 34" stroke-width="10" ' + S + '/><path d="M22 34 L38 34 M90 34 L106 34" stroke-width="12" ' + S + '/><circle cx="28" cy="98" r="7" fill="currentColor"/><circle cx="52" cy="98" r="7" fill="currentColor"/><circle cx="76" cy="98" r="7" fill="currentColor"/><circle cx="100" cy="98" r="7" fill="currentColor"/>'
};
let token = null;
try { token = localStorage.getItem('pd_token'); } catch (e) {}
if (!token) { token = Math.random().toString(36).slice(2, 10); try { localStorage.setItem('pd_token', token); } catch (e) {} }
let ws = null, ready = false;
const status = document.getElementById('status'), badge = document.getElementById('badge');
function connect() {
  ws = new WebSocket('ws://' + location.hostname + ':' + PORT);
  ws.onopen = () => { ready = true; ws.send('hello ' + token); status.textContent = 'connected'; };
  ws.onclose = () => { ready = false; status.textContent = 'reconnecting…'; setTimeout(connect, 1000); };
  ws.onmessage = (ev) => {
    const m = ev.data.split(' ');
    if (m[0] === 'p') {
      badge.textContent = 'P' + m[1];
      badge.style.background = '#' + m[2];
      badge.style.color = '#14121c';
      status.textContent = 'you are player ' + m[1];
      badge.classList.add('hi'); setTimeout(() => badge.classList.remove('hi'), 300);
    } else if (m[0] === 'j') {
      // Your job: its icon and name in the job's colour
      const job = document.getElementById('job');
      job.style.display = 'flex';
      job.style.color = '#' + m[2];
      const parts = (m[3] || '').replace(/_/g, ' ').split('|');
      document.getElementById('jname').textContent = parts[0] + ' · ' + (parts[1] || '');
      document.getElementById('jicon').innerHTML = ICONS[m[1]] || '';
    } else if (m[0] === 'v') {
      // Haptics: the poker's rumble, a hammer blow, a clamp closing
      buzz((m[1] || '30').split(',').map(Number));
    } else if (m[0] === 'full') {
      status.textContent = 'the crew is full (4 players)';
    } else if (m[0] === 'c') {
      // What the game is asking for: button:verb:hold progress:urgent
      const want = {};
      (m[1] || '').split(',').forEach(s => { if (s) { const f = s.split(':'); want[f[0]] = {verb: (f[1] || '').replace(/_/g, ' '), p: parseFloat(f[2] || '-1'), urgent: f[3] === '1', gold: f[4] === '1'}; } });
      ['A', 'B', 'X', 'Y'].forEach(b => {
        const el = document.getElementById(b), w = want[b];
        el.classList.toggle('cue', !!w);
        el.classList.toggle('urgent', !!(w && w.urgent));
        el.classList.toggle('hold', !!(w && w.p >= 0));
        const g = !!(w && w.gold);
        if (g && !el.classList.contains('gold')) { goldBurst(el); buzz(15); }
        el.classList.toggle('gold', g);
        if (w && w.p >= 0) el.style.setProperty('--p', Math.min(1, w.p));
        if (w && w.verb) el.querySelector('.verb').textContent = w.verb;
        // A hold finishing: a big burst
        if (w && w.p >= 0.99 && !el.dataset.done) { el.dataset.done = '1'; burst(el, 34, 1.6); buzz([20, 30, 40]); }
        if (!w || w.p < 0.5) delete el.dataset.done;
      });
    }
  };
}
function send(t) { if (ready) ws.send(t); }
let haptics = true;
function buzz(p) { if (haptics && navigator.vibrate) { try { navigator.vibrate(p); } catch (e) {} } }
// Sparks: a little canvas of particles over everything
const fx = document.getElementById('fx'), g = fx.getContext('2d');
let parts = [], dpr = 1;
function resize() { dpr = Math.min(2, window.devicePixelRatio || 1); fx.width = innerWidth * dpr; fx.height = innerHeight * dpr; }
addEventListener('resize', resize); resize();
function colorOf(el) { return getComputedStyle(el).getPropertyValue('--hi').trim() || '#fff'; }
function burst(el, n, k) {
  const r = el.getBoundingClientRect(), cx = r.left + r.width / 2, cy = r.top + r.height / 2, col = colorOf(el);
  for (let i = 0; i < n; i++) {
    const a = Math.random() * Math.PI * 2, sp = (180 + Math.random() * 420) * k;
    parts.push({x: cx + Math.cos(a) * r.width * .45, y: cy + Math.sin(a) * r.width * .45, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp - 80, life: 0, max: .35 + Math.random() * .35, size: (2 + Math.random() * 4) * k, col: Math.random() < .25 ? '#ffffff' : col, star: Math.random() < .3});
  }
}
// Gold: the moment (or the spot) to press it. A shower of gold sparks, then a
// gentle trickle for as long as it stays gold
function goldBurst(el) {
  const r = el.getBoundingClientRect(), cx = r.left + r.width / 2, cy = r.top + r.height / 2;
  for (let i = 0; i < 26; i++) {
    const a = Math.random() * Math.PI * 2, sp = 160 + Math.random() * 360;
    parts.push({x: cx + Math.cos(a) * r.width * .5, y: cy + Math.sin(a) * r.width * .5, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp - 120, life: 0, max: .4 + Math.random() * .4, size: 2 + Math.random() * 4, col: Math.random() < .3 ? '#ffffff' : '#ffd23f', star: Math.random() < .5});
  }
}
setInterval(() => {
  document.querySelectorAll('.btn.gold').forEach(el => {
    const r = el.getBoundingClientRect(), a = Math.random() * Math.PI * 2;
    parts.push({x: r.left + r.width / 2 + Math.cos(a) * r.width * .55, y: r.top + r.height / 2 + Math.sin(a) * r.width * .55, vx: Math.cos(a) * 60, vy: -90 - Math.random() * 60, life: 0, max: .5, size: 2.5, col: '#ffd23f', star: true});
  });
}, 70);
let last = performance.now();
function frame(now) {
  const dt = Math.min(.05, (now - last) / 1000); last = now;
  g.setTransform(dpr, 0, 0, dpr, 0, 0);
  g.clearRect(0, 0, innerWidth, innerHeight);
  g.globalCompositeOperation = 'lighter';
  parts = parts.filter(q => (q.life += dt) < q.max);
  for (const q of parts) {
    q.vx *= 1 - 4 * dt; q.vy = q.vy * (1 - 4 * dt) + 600 * dt;
    q.x += q.vx * dt; q.y += q.vy * dt;
    const t = 1 - q.life / q.max;
    g.globalAlpha = t; g.fillStyle = q.col;
    if (q.star) { g.save(); g.translate(q.x, q.y); g.rotate(q.life * 9); g.fillRect(-q.size * t * 1.4, -q.size * .25, q.size * t * 2.8, q.size * .5); g.fillRect(-q.size * .25, -q.size * t * 1.4, q.size * .5, q.size * t * 2.8); g.restore(); }
    else { g.beginPath(); g.arc(q.x, q.y, q.size * (.4 + .6 * t), 0, 6.283); g.fill(); }
  }
  g.globalAlpha = 1; g.globalCompositeOperation = 'source-over';
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);
const flash = document.getElementById('flash');
function flashCol(el) {
  flash.style.background = 'radial-gradient(120% 120% at ' + (el.id === 'A' || el.id === 'B' ? '75%' : '60%') + ' 50%,transparent 55%,' + colorOf(el) + '55 100%)';
  flash.classList.remove('go'); void flash.offsetWidth; flash.classList.add('go');
}
// Buttons: squash in, ripple, sparks and a buzz on the way down; spring back up
['A', 'B', 'X', 'Y'].forEach(b => {
  const el = document.getElementById(b);
  const down = (e) => {
    e.preventDefault();
    try { el.setPointerCapture(e.pointerId); } catch (err) {}
    if (el.classList.contains('down')) return;
    el.classList.remove('boing'); el.classList.add('down');
    send('d ' + b);
    const rp = document.createElement('div'); rp.className = 'ripple'; el.appendChild(rp);
    rp.addEventListener('animationend', () => rp.remove());
    burst(el, b === 'A' ? 18 : 12, 1);
    flashCol(el);
    buzz(b === 'A' ? 18 : 12);
  };
  const up = (e) => {
    if (!el.classList.contains('down')) return;
    el.classList.remove('down');
    void el.offsetWidth; el.classList.add('boing');
    send('u ' + b);
    burst(el, 5, .6);
    buzz(6);
  };
  el.addEventListener('pointerdown', down);
  el.addEventListener('pointerup', up);
  el.addEventListener('pointercancel', up);
  el.addEventListener('lostpointercapture', up);
  el.addEventListener('animationend', (e) => { if (e.animationName === 'boing') el.classList.remove('boing'); });
});
// Stick: touch anywhere on the left half, it centres under your thumb
const left = document.getElementById('left'), base = document.getElementById('base'), knob = document.getElementById('knob'), wedge = document.getElementById('wedge');
let sid = null, ox = 0, oy = 0, lastSend = 0, vx = 0, vy = 0, atEdge = false;
function radius() { return base.getBoundingClientRect().width / 2; }
function setKnob(dx, dy) { knob.style.transform = 'translate(calc(-50% + ' + dx + 'px), calc(-50% + ' + dy + 'px))'; }
let stickTimer = null;
function sendStick(force) {
  const now = performance.now();
  if (force || now - lastSend > 33) {
    lastSend = now;
    if (stickTimer) { clearTimeout(stickTimer); stickTimer = null; }
    send('m ' + vx.toFixed(2) + ' ' + vy.toFixed(2));
  } else if (!stickTimer) {
    // (a move inside the throttle still gets there: the last position
    // always arrives, so the boom stops where your thumb stopped)
    stickTimer = setTimeout(() => { stickTimer = null; sendStick(true); }, 34 - (now - lastSend));
  }
}
left.addEventListener('pointerdown', (e) => {
  e.preventDefault(); sid = e.pointerId; left.setPointerCapture(sid);
  const r = left.getBoundingClientRect();
  ox = e.clientX; oy = e.clientY;
  base.style.left = (ox - r.left) + 'px'; base.style.top = (oy - r.top) + 'px';
  base.classList.add('on');
  buzz(8);
});
left.addEventListener('pointermove', (e) => {
  if (e.pointerId !== sid) return;
  const R = radius();
  let dx = e.clientX - ox, dy = e.clientY - oy;
  const d = Math.hypot(dx, dy);
  if (d > R) { dx *= R / d; dy *= R / d; }
  setKnob(dx, dy);
  vx = dx / R; vy = dy / R;
  const mag = Math.min(1, d / R);
  // The rim lights up the way you're pushing
  wedge.style.opacity = mag;
  wedge.style.transform = 'rotate(' + (Math.atan2(dy, dx) * 180 / Math.PI + 90) + 'deg)';
  if (mag >= 1 && !atEdge) { atEdge = true; buzz(5); }
  if (mag < .9) atEdge = false;
  sendStick(false);
});
function endStick(e) {
  if (e.pointerId !== sid) return;
  sid = null; vx = 0; vy = 0; setKnob(0, 0); sendStick(true);
  base.style.left = '50%'; base.style.top = '55%';
  base.classList.remove('on'); wedge.style.opacity = 0;
}
left.addEventListener('pointerup', endStick);
left.addEventListener('pointercancel', endStick);
// Full screen: Android goes full screen on a tap; an iPhone can't from a web
// page, so it's opened from the home screen instead, where it runs like an app
const de = document.documentElement;
const standalone = (window.navigator.standalone === true) || matchMedia('(display-mode: fullscreen), (display-mode: standalone)').matches;
const canFs = !!(de.requestFullscreen || de.webkitRequestFullscreen);
const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
if (isIOS && !standalone) document.getElementById('ios').style.display = 'block';
function goFull() {
  if (standalone) return;
  const f = de.requestFullscreen || de.webkitRequestFullscreen;
  if (f) { try { const r = f.call(de, {navigationUI: 'hide'}); if (r && r.catch) r.catch(() => {}); } catch (e) {} }
  if (screen.orientation && screen.orientation.lock) screen.orientation.lock('landscape').catch(() => {});
}
const fsBtn = document.getElementById('fs');
function fsShow() { fsBtn.style.display = (canFs && !isIOS && !standalone && !(document.fullscreenElement || document.webkitFullscreenElement)) ? 'flex' : 'none'; }
document.addEventListener('fullscreenchange', fsShow);
document.addEventListener('webkitfullscreenchange', fsShow);
fsBtn.addEventListener('pointerdown', (e) => { e.preventDefault(); goFull(); });
// Pause: the game's menu, steered from here with the stick, A and B
const menuBtn = document.getElementById('menu');
menuBtn.addEventListener('pointerdown', (e) => { e.preventDefault(); menuBtn.classList.add('down'); send('d MENU'); buzz(15); });
menuBtn.addEventListener('pointerup', () => { menuBtn.classList.remove('down'); });
// First tap: go full screen and join
document.getElementById('gate').addEventListener('pointerdown', () => {
  document.getElementById('gate').style.display = 'none';
  goFull();
  setTimeout(fsShow, 400);
});
connect();
</script>
</body>
</html>
"""
