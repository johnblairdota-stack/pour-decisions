## The phone controller page served by phones.gd, in the Site Kit look (the
## TV's button prompts use the same colours, shapes, motion and buzzes).
##
##   Lobby    pick your job (jobs other people have are greyed with their P
##            tag), hold LOCK IN; then today's crew and the countdown.
##   On site  the Job Ticket: a stick zone on the left that never covers
##            anything else, your job ticket in the middle with the step
##            you're on lit up, A / B / X / Y on the right. Tap the ticket's
##            header to flip it and swap to a job a bot's doing (hold to
##            confirm). The pump operator's ticket carries the live gauge.
##   Nudges   the edge glows when the game's waiting on you, then a ghost
##            thumb shows which button, then the leading hand helps.
## (No backslashes in here: GDScript would read them as escapes.)
extends RefCounted

const MANIFEST := '{"name": "Pour Decisions controller", "short_name": "Pour Decisions", "start_url": "/", "display": "fullscreen", "orientation": "landscape", "background_color": "#0b0c10", "theme_color": "#0b0c10", "icons": [{"src": "/icon.png", "sizes": "192x192", "type": "image/png"}]}'

static func html(ws_port: int) -> String:
	return PAGE.replace("__WS_PORT__", str(ws_port)).replace("__ICONS__", JSON.stringify(_icons()))

const Icons := preload("res://scripts/icons.gd")
static var _icon_uris := {}

## The jobs' icons as PNG data (white on clear, tinted on the phone through a
## mask), the same ones the TV draws on the hats.
static func _icons() -> Dictionary:
	if _icon_uris.is_empty():
		for role in Icons.ROLES:
			var png: PackedByteArray = Icons.texture(role, 96).get_image().save_png_to_buffer()
			_icon_uris[role] = "data:image/png;base64," + Marshalls.raw_to_base64(png)
	return _icon_uris

const PAGE := """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no,viewport-fit=cover">
<meta name="theme-color" content="#0b0c10">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="apple-mobile-web-app-title" content="Pour Decisions">
<link rel="manifest" href="/manifest.json">
<link rel="apple-touch-icon" href="/icon.png">
<title>Pour Decisions controller</title>
<style>
@font-face{font-family:"Barlow Condensed";src:url(/font/head.ttf) format("truetype");font-weight:800;font-display:swap}
@font-face{font-family:"Barlow";src:url(/font/body.ttf) format("truetype");font-weight:600;font-display:swap}
:root{--bg:#0b0c10;--card:#15171d;--track:#1a1d24;--bone:#f4f2ec;--muted:#9a978f;--dim:#5d606b;--gold:#ffd23f;--alarm:#ff3b2f;--done:#4fb36b;--paper:#f3efe4;--job:#ffc72c;--me:#3d8bff}
*{box-sizing:border-box;-webkit-tap-highlight-color:transparent;user-select:none;-webkit-user-select:none;touch-action:none}
html,body{margin:0;height:100%;touch-action:none;-webkit-text-size-adjust:100%;text-size-adjust:100%;overscroll-behavior:none;position:fixed;inset:0;width:100%;background:var(--bg);color:var(--bone);font-family:Barlow,system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;font-weight:600;overflow:hidden}
.hd{font-family:"Barlow Condensed","Arial Narrow",system-ui,sans-serif;font-weight:800}
button{font:inherit;color:inherit;border:0;background:none;padding:0;cursor:pointer}
.screen{position:fixed;inset:0;display:none}
.screen.on{display:block}
#fx{position:fixed;inset:0;width:100%;height:100%;pointer-events:none;z-index:30}
/* --- the edge glow: the game's waiting on you (job colour), gold moment, alarm */
#edge{position:fixed;inset:0;pointer-events:none;z-index:25;opacity:0;transition:opacity .3s;box-shadow:inset 0 0 0 .8vmin var(--glow,var(--job)),inset 0 0 7vmin var(--glow,var(--job))}
#edge.on{opacity:1;animation:edge 1.2s ease-in-out infinite}
#edge.alarm{--glow:var(--alarm);opacity:1;animation:edgefast .3s linear infinite}
@keyframes edge{0%,100%{opacity:.45}50%{opacity:1}}
@keyframes edgefast{0%,100%{opacity:.3}50%{opacity:1}}
/* --- toast */
#toast{position:fixed;left:50%;top:2vmin;transform:translate(-50%,-160%);background:var(--card);border:2px solid #3a3d47;border-radius:99px;padding:1.4vmin 3.4vmin;font-size:3.6vmin;z-index:40;transition:transform .3s cubic-bezier(.3,1.5,.5,1)}
#toast.on{transform:translate(-50%,0)}
/* --- top bar bits */
.pausebtn{position:absolute;left:2vmin;top:2.6vmin;width:11vmin;height:10vmin;border-radius:2.6vmin;border:1px solid #3a3d47;background:var(--card);display:flex;align-items:center;justify-content:center;z-index:12}
.pausebtn svg{width:4.6vmin;height:4.6vmin}
.pausebtn.down{transform:scale(.92);background:#2a2d36}
#fs{position:fixed;right:2vmin;top:2.6vmin;width:10vmin;height:10vmin;border-radius:2.6vmin;border:1px solid #3a3d47;background:rgba(21,23,29,.8);display:none;align-items:center;justify-content:center;z-index:12}
#fs svg{width:5vmin;height:5vmin}
/* --- play: stick zone */
#zone{position:absolute;left:1.6vw;top:18vh;width:31vw;bottom:3vh;border:2px dashed #23262e;border-radius:5vmin}
#zone .lbl{position:absolute;left:3vmin;bottom:2.4vmin;font-size:2.6vmin;color:#3a3e4a;letter-spacing:.08em;text-transform:uppercase}
#zone.off{opacity:.35}
#base{position:absolute;width:38vmin;height:38vmin;border-radius:50%;border:2px solid #3a3e4a;left:50%;top:50%;transform:translate(-50%,-50%);transition:border-color .2s,box-shadow .2s;pointer-events:none}
#base.on{border-color:rgba(255,255,255,.55);box-shadow:inset 0 0 6vmin rgba(255,255,255,.08)}
#wedge{position:absolute;inset:-2px;border-radius:50%;opacity:0;background:conic-gradient(from -30deg,var(--job),transparent 60deg,transparent 360deg);-webkit-mask:radial-gradient(farthest-side,transparent 82%,#000 84%);mask:radial-gradient(farthest-side,transparent 82%,#000 84%)}
/* dogman: the crane's calls round the stick */
.call{position:absolute;left:50%;top:50%;display:none;font-family:"Barlow Condensed",sans-serif;font-weight:800;font-size:3.2vmin;line-height:1;text-align:center;white-space:pre;color:#e8e6df;background:rgba(12,14,18,.88);border:1px solid #3a3e4a;padding:.8vmin 1.4vmin;border-radius:2vmin}
.call.lit{color:#111;background:#ffd23f;border-color:#ffd23f}
#zone.dog .call{display:block}
#zone.dog .lbl{color:#ff8a80}
#knob{position:absolute;width:16vmin;height:16vmin;border-radius:50%;background:radial-gradient(circle at 40% 35%,#ffffff,#d9d5cb);box-shadow:0 1.2vmin 0 #8f8a7e,0 2vmin 4vmin rgba(0,0,0,.6);left:50%;top:50%;transform:translate(-50%,-50%)}
/* --- play: the ticket */
#ticket{position:absolute;left:34vw;width:33vw;top:2.6vmin;bottom:2.6vmin;border-radius:4.6vmin;background:var(--paper);color:#1b1a17;overflow:hidden;display:flex;flex-direction:column;box-shadow:0 3vmin 7vmin rgba(0,0,0,.5);transition:transform .45s cubic-bezier(.3,1.3,.5,1)}
#thead{display:flex;align-items:center;gap:2.4vmin;background:var(--job);color:#111;padding:2.2vmin 2.8vmin;text-align:left;width:100%}
#thead svg.hat{width:8vmin;height:7vmin;flex-shrink:0}
#thead .tt{display:flex;flex-direction:column;line-height:1;flex-grow:1;min-width:0}
#thead .k{font-size:3vmin;letter-spacing:.08em;opacity:.8}
#thead .n{font-size:6.4vmin;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
#thead .sw{display:flex;align-items:center;gap:1vmin;font-size:3vmin;background:rgba(0,0,0,.12);padding:1.4vmin 2vmin;border-radius:2.4vmin;flex-shrink:0}
#thead .sw svg{width:3.8vmin;height:3.8vmin}
#thead:active{filter:brightness(1.1)}
#goal{padding:1.6vmin 2.8vmin;font-size:3.3vmin;border-bottom:1px dashed #c9c4b5}
#steps{padding:1.6vmin 2.4vmin;display:flex;flex-direction:column;gap:1.3vmin;flex-grow:1;overflow:hidden}
.st{display:flex;gap:1.8vmin;align-items:flex-start;font-size:3.3vmin;line-height:1.25;padding:.6vmin;border-radius:2.6vmin;border:2px solid transparent}
.st .k{min-width:5.6vmin;height:5.6vmin;padding:0 1vmin;border-radius:99px;display:flex;align-items:center;justify-content:center;font-family:"Barlow Condensed",sans-serif;font-weight:800;font-size:3.4vmin;flex-shrink:0}
.st.now{background:#fff6d6;border-color:var(--gold);font-weight:700;animation:nowpulse 1.4s ease-in-out infinite}
.st.past{color:#8c887d}
.st.go{background:color-mix(in srgb,var(--job) 22%,#fff);border-color:var(--job);font-weight:800;font-size:4vmin;align-items:center}
.st.go svg{width:5.6vmin;height:5.6vmin;flex-shrink:0}
.st.brief{flex-direction:column;align-items:stretch;gap:1.4vmin}
.st.brief .bar{height:2.2vmin;border-radius:99px;background:#e2dccb;overflow:hidden}
.st.brief .bar i{display:block;height:100%;background:var(--gold);width:0}
#ljobs .job .q{font-size:3.3vmin;color:var(--bone);font-weight:700;line-height:1.2}
.st .v{display:block;font-size:2.8vmin;color:#7a5a00;margin-top:.4vmin}
@keyframes nowpulse{0%,100%{box-shadow:0 0 0 0 rgba(255,210,63,0)}50%{box-shadow:0 0 0 1vmin rgba(255,210,63,.3)}}
#tfoot{padding:1.4vmin 2.8vmin 2vmin;background:#e6e0d0;font-size:2.8vmin;color:#4d4a42}
#tfoot b{color:#1b1a17}
/* pump: the live gauge on the ticket */
#gauge{display:none;position:relative;width:34vmin;height:25vmin;margin:1.4vmin auto 0}
#gauge svg{width:100%;height:20vmin;display:block}
#gauge .read{position:absolute;left:0;right:0;bottom:0;text-align:center;font-size:4.6vmin;line-height:1}
#needle{transform-origin:50px 50px;transition:transform .15s}
.pump #gauge{display:block}
.pump #steps{gap:.6vmin}
.pump #goal{display:none}
/* --- play: the buttons */
#pad{position:absolute;left:68vw;right:0;top:0;bottom:0}
.btn{position:absolute;--p:-1;--s:1;--face:#3fe0c5;--lip:#1b8a6e;--ink:#04281f;--hi:#3fe0c5}
.face{position:absolute;inset:0;border-radius:50%;display:flex;align-items:center;justify-content:center;font-family:"Barlow Condensed",sans-serif;font-weight:800;color:var(--ink);background:radial-gradient(circle at 40% 30%,color-mix(in srgb,var(--face) 60%,#fff),var(--face) 62%);box-shadow:0 1.4vmin 0 var(--lip),0 2.6vmin 4vmin rgba(0,0,0,.5);transform:translateY(0) scale(var(--s));transition:transform .2s cubic-bezier(.3,1.8,.5,1);overflow:hidden}
.face span{position:relative;font-size:9vmin;line-height:1;z-index:2}
.face .wet{position:absolute;left:0;right:0;bottom:0;height:0;background:linear-gradient(#b9b5ac,#8f8b82);opacity:.75;z-index:1;transition:height .1s linear}
.face .wet::before{content:"";position:absolute;left:-10%;right:-10%;top:-1.2vmin;height:2.4vmin;border-radius:50%;background:#b9b5ac}
.btn.down .face{transform:translateY(1.1vmin) scale(.9);box-shadow:0 .3vmin 0 var(--lip),0 0 6vmin color-mix(in srgb,var(--face) 50%,transparent);transition:transform .09s ease-out,box-shadow .09s}
.btn.boing .face{animation:boing .38s cubic-bezier(.3,1.6,.5,1)}
@keyframes boing{0%{transform:translateY(1.1vmin) scale(.9)}45%{transform:translateY(-.5vmin) scale(1.06)}100%{transform:translateY(0) scale(1)}}
.ring{position:absolute;inset:-2.6vmin;border-radius:50%;opacity:0;background:conic-gradient(var(--ringc,#fff) calc(var(--p) * 1turn),var(--track) 0);-webkit-mask:radial-gradient(farthest-side,transparent calc(100% - 1.4vmin),#000 calc(100% - 1.3vmin));mask:radial-gradient(farthest-side,transparent calc(100% - 1.4vmin),#000 calc(100% - 1.3vmin))}
.btn.hold .ring{opacity:1}
.verb{position:absolute;left:50%;top:100%;margin-top:3.2vmin;display:flex;align-items:center;gap:1.2vmin;padding:.8vmin 2.4vmin .8vmin 1.6vmin;border-radius:99px;background:rgba(26,29,36,.94);font-family:"Barlow Condensed",sans-serif;font-weight:800;font-size:3.6vmin;color:var(--bone);white-space:nowrap;opacity:0;transform:translate(-50%,-1.5vmin) scale(.85);transition:opacity .15s,transform .2s cubic-bezier(.3,1.8,.5,1);pointer-events:none}
.verb i{width:2vmin;height:2vmin;border-radius:50%;background:var(--job);flex-shrink:0}
.btn.cue .verb{opacity:1;transform:translate(-50%,0) scale(1)}
.btn.cue .face{animation:breathe 2.4s ease-in-out infinite}
.btn.cue.urgent .face{animation:urgent .5s ease-in-out infinite}
.btn.cue.alarm{--face:#ff3b2f;--lip:#8e1c14;--ink:#fff}
.btn.cue.alarm .face{animation:shake .15s linear infinite}
.btn.cue.alarm .verb{color:#ff8b80;box-shadow:0 0 0 2px var(--alarm)}
.btn.cue.alarm .verb i{background:var(--alarm)}
.btn.gold{--face:#ffd23f;--lip:#b17a00;--ink:#2a1d00;--ringc:#ffd23f}
.btn.gold .face{animation:goldbeat .3s ease-in-out infinite;box-shadow:0 1.4vmin 0 var(--lip),0 0 0 calc(1.2vmin * var(--gl,1)) rgba(255,210,63,.35),0 0 calc(8vmin * var(--gl,1)) rgba(255,210,63,calc(.8 * var(--gl,1)))}
.btn.gold.faint .face{animation:none}
.btn.gold .verb{color:var(--gold);box-shadow:0 0 0 2px var(--gold);text-transform:uppercase}
.btn.down .face,.btn.boing .face{animation-name:none}
.btn.down.gold .face{animation:none}
.btn.dim .face{filter:saturate(.5) brightness(.6)}
@keyframes breathe{0%,100%{transform:scale(1)}50%{transform:scale(1.06)}}
@keyframes urgent{0%,100%{transform:scale(1)}50%{transform:scale(1.14)}}
@keyframes goldbeat{0%,100%{transform:scale(1.04)}50%{transform:scale(1.14)}}
@keyframes shake{0%,100%{transform:translate(0,0)}25%{transform:translate(-.6vmin,.3vmin)}50%{transform:translate(.4vmin,-.4vmin)}75%{transform:translate(-.4vmin,.4vmin)}}
#Y{width:17vmin;height:17vmin;left:36%;top:6%;--face:#ffc23d;--lip:#b17a00;--ink:#2a1d00}
#B{width:17vmin;height:17vmin;left:70%;top:20%;--face:#ff5a5f;--lip:#9b2525;--ink:#2b0606}
#X{width:17vmin;height:17vmin;left:2%;top:36%;--face:#9b6bff;--lip:#5a35b0;--ink:#1b0d3a}
#A{width:27vmin;height:27vmin;left:30%;top:43%;--face:#3fe0c5;--lip:#1b8a6e;--ink:#04281f}
#A .face span{font-size:13vmin}
#Y .verb{top:50%;left:auto;right:100%;margin:0 3vmin 0 0;transform:translate(0,-50%) scale(.85)}
#Y.cue .verb{transform:translate(0,-50%) scale(1)}
#B .verb{left:auto;right:-2vmin;transform:translate(0,-1.5vmin) scale(.85)}
#B.cue .verb{transform:translate(0,0) scale(1)}
#X .verb{left:0;transform:translate(0,-1.5vmin) scale(.85)}
#X.cue .verb{transform:translate(0,0) scale(1)}
/* a hint of a thumb, tapping the button the game's waiting on */
#ghost{position:fixed;width:16vmin;height:16vmin;pointer-events:none;z-index:26;display:none}
#ghost.on{display:block;animation:tap 1.1s ease-in-out infinite}
#ghost div{position:absolute;left:30%;top:20%;width:40%;height:62%;border-radius:45% 45% 40% 40%;background:rgba(255,255,255,.55);border:.5vmin solid rgba(255,255,255,.9);box-shadow:0 0 4vmin rgba(255,255,255,.5)}
@keyframes tap{0%,100%{transform:translate(4vmin,6vmin) scale(1);opacity:.2}45%{transform:translate(0,0) scale(.92);opacity:1}60%{transform:translate(0,0) scale(.86);opacity:1}}
#helping{position:absolute;left:34vw;width:33vw;bottom:4vmin;z-index:14;background:#ffe95a;border:0.6vmin solid #c8170f;color:#1d1a14;border-radius:3vmin;padding:1.6vmin 2.4vmin;font-size:3.1vmin;display:none}
#helping.on{display:block;animation:spray .16s infinite}
#helping b{display:block;color:#a10d0d;font-size:4.2vmin;font-weight:800;line-height:1.1;margin-bottom:.6vmin}
@keyframes spray{0%{transform:translate(0,0) rotate(-1deg)}50%{transform:translate(.4vmin,-.3vmin) rotate(1deg)}100%{transform:translate(-.3vmin,.2vmin) rotate(-.5deg)}}
/* --- swap panel */
#swap{position:absolute;left:20vw;width:60vw;top:2.6vmin;bottom:2.6vmin;border-radius:4.6vmin;background:#1b1e26;border:2px solid #3a3e4a;padding:3vmin;display:none;flex-direction:column;gap:2vmin;box-shadow:0 4vmin 9vmin rgba(0,0,0,.6);z-index:15;animation:flip .45s cubic-bezier(.3,1.3,.5,1) both}
#swap.on{display:flex}
@keyframes flip{0%{transform:perspective(160vmin) rotateY(-90deg)}100%{transform:perspective(160vmin) rotateY(0)}}
#swap .top{display:flex;align-items:center;gap:2vmin}
#swap .top .t{font-size:6vmin;flex-grow:1}
#swap .x{width:10vmin;height:10vmin;border-radius:2.6vmin;border:1px solid #3a3d47;display:flex;align-items:center;justify-content:center}
#swap .x svg{width:4.4vmin;height:4.4vmin}
#jobs{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:1.8vmin;flex-grow:1}
.job{display:flex;flex-direction:column;justify-content:center;gap:.6vmin;border-radius:3vmin;padding:1.6vmin 2vmin;text-align:left;border:2px solid var(--c);background:color-mix(in srgb,var(--c) 12%,#14161b)}
.job .n{font-family:"Barlow Condensed",sans-serif;font-weight:800;font-size:4.6vmin;color:var(--c);display:flex;align-items:center;gap:1.4vmin}
.job .n svg{width:6vmin;height:5vmin;flex-shrink:0}
.job .w{font-size:2.8vmin;color:#b9b6ad}
.job.pick{box-shadow:0 0 0 1vmin color-mix(in srgb,var(--c) 35%,transparent);transform:translateY(-.5vmin)}
.job.mine{opacity:.85}
.job.taken{border-color:#23262e;background:#14161b;opacity:.5}
.job.taken .n{color:#9a978f}
.ptag{font-family:"Barlow Condensed",sans-serif;font-weight:800;font-size:2.8vmin;padding:.2vmin 1.4vmin;border-radius:99px;color:#111;margin-left:auto}
.holdbtn{position:relative;overflow:hidden;border-radius:3vmin;background:#2a2d36;color:#fff;font-family:"Barlow Condensed",sans-serif;font-weight:800;font-size:4.8vmin;letter-spacing:.04em;padding:2.4vmin 5vmin;min-width:44vmin;box-shadow:0 1vmin 0 #15171d}
.holdbtn .fill{position:absolute;left:0;top:0;bottom:0;width:0;background:linear-gradient(90deg,#8f8b82,#b9b5ac)}
.holdbtn span{position:relative}
.holdbtn:disabled{opacity:.35}
.holdbtn.down{transform:translateY(.6vmin);box-shadow:0 .4vmin 0 #15171d}
#swap .bottom{display:flex;align-items:center;gap:3vmin}
#swap .note{font-size:3vmin;color:#9a978f;flex-grow:1}
/* --- lobby */
#lobby{padding:3vmin 4vmin;flex-direction:column;gap:2.4vmin}
#lobby.on,#locked.on{display:flex}
.row{display:flex;align-items:center;gap:2.4vmin}
.pdisc{width:9vmin;height:9vmin;border-radius:50%;display:flex;align-items:center;justify-content:center;font-family:"Barlow Condensed",sans-serif;font-weight:800;font-size:4vmin;color:#111;flex-shrink:0;box-shadow:0 .8vmin 0 rgba(0,0,0,.35)}
#lobby .t{font-size:6.6vmin;flex-grow:1}
#lobby .sub{font-size:3.4vmin;color:#b9b6ad}
#ljobs{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:2vmin;flex-grow:1}
#ljobs .job{background:#1a1c23;border-color:#2c2f39}
#ljobs .job .n{color:var(--bone)}
#ljobs .job .n .sq{width:7vmin;height:7vmin;border-radius:2vmin;background:var(--c);display:flex;align-items:center;justify-content:center;color:#111;flex-shrink:0}
#ljobs .job .n .sq svg{width:6.4vmin;height:5.4vmin}
#ljobs .job.mine{background:#22242c;border:3px solid var(--me);box-shadow:0 0 0 1vmin color-mix(in srgb,var(--me) 25%,transparent);transform:translateY(-.5vmin);opacity:1}
#ljobs .job.taken{opacity:.45}
.charpick{display:flex;align-items:center;gap:1.4vmin;font-size:4.2vmin}
.charpick button{width:9vmin;height:9vmin;border-radius:2.4vmin;background:#1a1c23;border:1px solid #2c2f39;font-size:4vmin}
#locked{padding:5vmin 6vmin;gap:6vmin;align-items:center;background:radial-gradient(100% 120% at 25% 55%,color-mix(in srgb,var(--job) 25%,#0d0f14) 0%,#0d0f14 65%)}
#locked .left{display:flex;flex-direction:column;align-items:center;gap:2vmin;width:56vmin;flex-shrink:0}
#lhat{width:40vmin;height:33vmin;color:var(--job);animation:drop .7s cubic-bezier(.3,1.4,.5,1) both}
@keyframes drop{0%{transform:translateY(-40vmin) rotate(-25deg)}55%{transform:translateY(2vmin) rotate(4deg) scaleY(.82) scaleX(1.12)}75%{transform:translateY(-1.4vmin) scale(1)}100%{transform:translateY(0)}}
#locked .k{font-size:3.6vmin;letter-spacing:.14em;color:var(--me)}
#locked .n{font-size:9vmin;line-height:1;text-align:center}
#locked .right{flex-grow:1;display:flex;flex-direction:column;gap:1.8vmin}
#crewlist{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:1.6vmin}
.cl{display:flex;align-items:center;gap:2vmin;background:#1a1c23;border-radius:2.6vmin;padding:1.6vmin 2.4vmin;font-size:3.4vmin}
.cl i{width:2.6vmin;height:7vmin;border-radius:1vmin;flex-shrink:0}
.cl span{flex-grow:1}
.cl.bot{background:#15171c;color:#9a978f}
.cl.me{border:2px solid var(--me)}
#count{font-size:10vmin;color:var(--gold);line-height:1}
/* --- joined splash */
#joined{position:fixed;inset:0;z-index:35;background:radial-gradient(120% 140% at 30% 50%,#1d2230 0%,#0d0f14 70%);display:none;align-items:center;gap:10vmin;padding:0 12vmin}
#joined.on{display:flex}
#joined .big{width:36vmin;height:36vmin;border-radius:50%;display:flex;align-items:center;justify-content:center;font-family:"Barlow Condensed",sans-serif;font-weight:800;font-size:18vmin;color:#111;box-shadow:0 2.4vmin 0 rgba(0,0,0,.35);animation:pop .7s cubic-bezier(.3,1.6,.5,1) both;flex-shrink:0}
@keyframes pop{0%{transform:scale(.2) rotate(-20deg)}60%{transform:scale(1.15) rotate(4deg)}100%{transform:scale(1) rotate(0)}}
#joined .k{font-size:4vmin;letter-spacing:.14em;text-transform:uppercase}
#joined .t{font-size:12vmin;line-height:.95}
#joined .s{font-size:3.8vmin;color:#b9b6ad;max-width:80vmin;margin-top:2vmin}
#pdots{display:flex;gap:2vmin;margin-top:3vmin}
#pdots div{width:9.6vmin;height:9.6vmin;border-radius:50%;display:flex;align-items:center;justify-content:center;font-family:"Barlow Condensed",sans-serif;font-weight:800;font-size:4vmin;color:#111;border:2px dashed #4a4d57}
/* --- gate, rotate */
#rotate,#gate{position:fixed;inset:0;background:var(--bg);display:none;align-items:center;justify-content:center;flex-direction:column;gap:3vmin;text-align:center;padding:6vmin;font-size:5vmin;z-index:50}
#gate{display:flex;cursor:pointer}
#gate .again,#gate.back .first{display:none}#gate.back #ios{display:none!important}#gate.back .again{display:inline}
#gate b{font-family:"Barlow Condensed",sans-serif;font-weight:800;font-size:10vmin;color:var(--gold)}
#gate .go{font-family:"Barlow Condensed",sans-serif;font-weight:800;background:var(--gold);color:#2a1d00;border-radius:3vmin;padding:2.4vmin 6vmin;box-shadow:0 1.2vmin 0 #b17a00}
#ios{display:none;max-width:80vmin;font-size:3.6vmin;color:#c9c6bd;line-height:1.4;border:1.5px solid rgba(255,255,255,.18);border-radius:3vmin;padding:2.4vmin 3vmin}
/* --- sign the slab: draw in the wet concrete with a finger */
#sign{background:radial-gradient(120% 120% at 50% 0%,#2a2c33 0%,#0b0c10 70%)}
#sign .side{position:absolute;left:4vmin;top:5vmin;bottom:5vmin;width:calc(100vw - 100vmin);min-width:30vmin;display:flex;flex-direction:column;gap:2.4vmin}
#sign .k{font-size:3.6vmin;letter-spacing:.14em;color:var(--gold)}
#sign .t{font-size:9vmin;line-height:.92}
#sign .s{font-size:3.4vmin;color:#c9c6bd;line-height:1.35}
#sign .left{font-size:6vmin;margin-top:auto}
#sign .row{display:flex;gap:2vmin}
#sign .row button{flex:1;min-height:12vmin;border-radius:3vmin;font-family:"Barlow Condensed",sans-serif;font-weight:800;font-size:5vmin;background:var(--card);border:1px solid #3a3d47}
#sign .row button.go{background:#3fe0c5;color:#04281f;border:0;box-shadow:0 1vmin 0 #1b8a6e}
#sign .row button:disabled{opacity:.4}
#slab{position:absolute;right:4vmin;top:5vmin;width:90vmin;height:90vmin;border-radius:4vmin;background:radial-gradient(80% 80% at 40% 35%,#a39d92 0%,#8a857b 60%,#6f6a61 100%);box-shadow:inset 0 0 0 .6vmin rgba(255,255,255,.08)}
#slab.done{opacity:.6}
#status{position:fixed;right:3vmin;bottom:2vmin;font-size:2.6vmin;color:var(--dim);z-index:12}
@media (orientation:portrait){#rotate{display:flex}}
@media (prefers-reduced-motion:reduce){*{animation-duration:.01s!important;animation-iteration-count:1!important}}
/* --- the wallet: cash banked, and the ute shop */
#walletbtn{position:fixed;left:15vmin;top:2.6vmin;height:10vmin;padding:0 2.6vmin;border-radius:2.6vmin;border:1px solid #3a3d47;background:var(--card);display:none;align-items:center;gap:1.6vmin;z-index:12;font-size:4vmin}
#walletbtn.on{display:flex}
#walletbtn svg{width:6vmin;height:5vmin}
#walletbtn b{color:#7cd992}
#walletbtn.bump{animation:wbump .5s cubic-bezier(.3,1.6,.5,1)}
@keyframes wbump{0%{transform:scale(1)}40%{transform:scale(1.18)}100%{transform:scale(1)}}
#wallet{position:fixed;inset:2.6vmin;border-radius:4.6vmin;background:#14161c;border:2px solid #3a3e4a;display:none;z-index:35;box-shadow:0 4vmin 9vmin rgba(0,0,0,.6);overflow:hidden}
#wallet.on{display:flex;animation:flip .45s cubic-bezier(.3,1.3,.5,1) both}
#wallet .wl{width:34%;padding:3vmin;display:flex;flex-direction:column;gap:1.4vmin;background:#1b1e26;border-right:1px solid #2c2f37}
#wallet .wl .k{font-size:3.2vmin;color:var(--muted);letter-spacing:.08em}
#wallet .wl .cash{font-size:11vmin;line-height:.9;color:#7cd992}
#wallet .wl .sub{font-size:3.4vmin;color:#b9b6ad}
#wallet .wl .purse svg{width:100%;height:26vmin;display:block}
#wallet .wr{flex:1;display:flex;flex-direction:column;min-width:0}
#wallet .tabs{display:flex;gap:1.2vmin;padding:2.4vmin 3vmin 1.4vmin;align-items:center}
#wallet .tabs button{font-size:4.2vmin;padding:1vmin 3vmin;border-radius:99px;background:#22252d;color:#b9b6ad}
#wallet .tabs button.on{background:var(--gold);color:#2a1d00}
#wallet .tabs .x{margin-left:auto;width:9vmin;height:9vmin;border-radius:50%;background:#22252d;display:flex;align-items:center;justify-content:center}
#wallet .tabs .x svg{width:4.4vmin;height:4.4vmin}
#wallet .body{flex:1;overflow-y:auto;padding:0 3vmin 3vmin;touch-action:pan-y}
#wallet .garage svg{width:100%;height:auto;max-height:44vmin;display:block}
#wallet .garage .n{font-size:5.4vmin}
#wallet .garage .kitl{font-size:3.2vmin;color:#b9b6ad;margin-top:1vmin}
#wallet .items{display:grid;grid-template-columns:1fr 1fr;gap:1.6vmin}
#wallet .it{background:#1f222a;border:2px solid #2c2f37;border-radius:2.6vmin;padding:2vmin 2.4vmin;text-align:left;display:flex;flex-direction:column;gap:.6vmin}
#wallet .it .n{font-size:4.2vmin}
#wallet .it .l{font-size:2.9vmin;color:#9a978f}
#wallet .it .pr{font-size:4vmin;color:#7cd992}
#wallet .it.pick{border-color:var(--gold)}
#wallet .it.have{opacity:.6}
#wallet .it.have .pr{color:var(--muted)}
#wallet .it.short .pr{color:#ff8a7a}
#wallet .buyrow{display:flex;gap:2vmin;align-items:center;padding:1.6vmin 3vmin 2.4vmin;border-top:1px solid #2c2f37}
#wallet .buyrow .note{flex:1;font-size:3.4vmin;color:#b9b6ad}
</style>
</head>
<body>
<canvas id="fx"></canvas>
<div id="edge"></div>
<div id="toast" class="hd"></div>

<div id="play" class="screen">
  <button class="pausebtn" aria-label="Pause"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round"><path d="M9 5v14M15 5v14"/></svg></button>
  <div id="zone"><div class="lbl">Stick</div><div id="base"><div id="wedge"></div><div class="call" id="call0"></div><div class="call" id="call1"></div><div class="call" id="call2"></div><div class="call" id="call3"></div><div id="knob"></div></div></div>
  <div id="ticket">
    <button id="thead" aria-label="Your job, tap to swap">
      <svg class="hat" id="thhat" viewBox="0 0 24 20"><path d="M1 16h22v2H1z M3.5 16v-3a8.5 8.5 0 0 1 17 0v3z" fill="currentColor"/></svg>
      <span class="tt hd"><span class="k" id="tk">YOUR JOB</span><span class="n" id="tn">…</span></span>
      <span class="sw hd" id="tsw"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M7 4L3 8l4 4"/><path d="M3 8h14"/><path d="M17 20l4-4-4-4"/><path d="M21 16H7"/></svg>SWAP</span>
    </button>
    <div id="goal"></div>
    <div id="gauge"><svg viewBox="0 0 100 56"><path d="M8 50 A42 42 0 0 1 92 50" fill="none" stroke="#1a1d24" stroke-width="9"/><path id="g1" fill="none" stroke-width="9"/><path id="g2" fill="none" stroke-width="9"/><path id="g3" fill="none" stroke-width="9"/><line id="needle" x1="50" y1="50" x2="50" y2="12" stroke="#1b1a17" stroke-width="3.4" stroke-linecap="round"/><circle cx="50" cy="50" r="5" fill="#1b1a17"/></svg><div class="read hd" id="gread">STEADY</div></div>
    <div id="steps"></div>
    <div id="tfoot"></div>
  </div>
  <div id="helping"><b></b><span></span></div>
  <div id="pad">
    <div class="btn" id="Y"><div class="ring"></div><div class="face"><div class="wet"></div><span>Y</span></div><div class="verb"><i></i><b></b></div></div>
    <div class="btn" id="B"><div class="ring"></div><div class="face"><div class="wet"></div><span>B</span></div><div class="verb"><i></i><b></b></div></div>
    <div class="btn" id="X"><div class="ring"></div><div class="face"><div class="wet"></div><span>X</span></div><div class="verb"><i></i><b></b></div></div>
    <div class="btn" id="A"><div class="ring"></div><div class="face"><div class="wet"></div><span>A</span></div><div class="verb"><i></i><b></b></div></div>
  </div>
  <div id="swap">
    <div class="top"><div class="t hd">Swap to a free job</div><button class="x" id="swapx" aria-label="Close"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round"><path d="M6 6l12 12M18 6L6 18"/></svg></button></div>
    <div id="jobs"></div>
    <div class="bottom"><div class="note" id="swapnote">Tap a job a bot's doing, then hold to swap. Your chibi stands still while this is open.</div><button class="holdbtn" id="swapgo" disabled><div class="fill"></div><span>HOLD TO SWAP</span></button></div>
  </div>
</div>

<div id="lobby" class="screen">
  <div class="row"><div class="pdisc" id="lp">P?</div><div class="t hd">Pick your job</div><div class="sub" id="lsub"></div></div>
  <div id="ljobs"></div>
  <div class="row">
    <div class="charpick"><button id="cprev" aria-label="Previous character" class="hd">&lt;</button><span class="hd" id="cname">…</span><button id="cnext" aria-label="Next character" class="hd">&gt;</button></div>
    <div class="sub" style="flex-grow:1">Tap a job, then hold LOCK IN. Greyed jobs belong to another player.</div>
    <button class="holdbtn" id="lockgo"><div class="fill"></div><span>HOLD TO LOCK IN</span></button>
  </div>
</div>

<div id="locked" class="screen">
  <div class="left">
    <svg id="lhat" viewBox="0 0 24 20"><path d="M1 16h22v2H1z M3.5 16v-3a8.5 8.5 0 0 1 17 0v3z" fill="currentColor"/></svg>
    <div class="k hd" id="lk">P? · LOCKED IN</div>
    <div class="n hd" id="ln">…</div>
    <button class="holdbtn" id="unlock" style="min-width:0;font-size:3.6vmin;padding:1.6vmin 4vmin;background:#1a1c23"><span>Change job</span></button>
  </div>
  <div class="right">
    <div class="hd" style="font-size:5vmin;color:#b9b6ad">Today's crew</div>
    <div id="crewlist"></div>
    <div class="row"><div id="count" class="hd"></div><div class="sub" id="cnote" style="font-size:3.4vmin;color:#b9b6ad">Waiting for the rest of the crew to lock in. Once you're on site you can swap to any job a bot is doing.</div></div>
  </div>
</div>

<div id="sign" class="screen">
  <div class="side">
    <div class="k hd" id="sgk">TOP-OUT · LEVEL 11</div>
    <div class="t hd">Sign the slab</div>
    <div class="s" id="sgs">Draw your initials, a hand, anything. It goes in the roof of Riverlight.</div>
    <div class="left hd" id="sgleft"></div>
    <div class="row"><button id="sgclr">CLEAR</button><button class="go" id="sgok">PRESS IT IN</button></div>
  </div>
  <canvas id="slab"></canvas>
</div>
<div id="joined"><div class="big" id="jbig">P?</div><div><div class="k hd" id="jk">You're on the crew</div><div class="t hd" id="jt">You are Player ?</div><div class="s">Look for your tag on the TV. Everyone scans the same code; the next phone gets the next number.</div><div id="pdots"></div></div></div>
<button id="walletbtn" aria-label="Your wallet"><svg viewBox="0 0 30 24"><rect x="1" y="4" width="28" height="18" rx="3" fill="#6b4a32"/><rect x="3" y="1" width="20" height="8" rx="1" fill="#3fae5a"/><rect x="1" y="7" width="28" height="15" rx="3" fill="#8a6142"/><circle cx="23" cy="14.5" r="2.4" fill="#e9c46a"/></svg><b class="hd" id="wbal">$0</b></button>
<div id="wallet">
  <div class="wl">
    <div class="k hd" id="wwho">WALLET</div>
    <div class="cash hd" id="wcash">$0</div>
    <div class="sub" id="wpour"></div>
    <div class="purse" id="wpurse"></div>
    <div class="sub" id="wbanked"></div>
  </div>
  <div class="wr">
    <div class="tabs"><button data-tab="garage" class="hd on">Your ute</button><button data-tab="utes" class="hd">Utes</button><button data-tab="4x4" class="hd">4x4</button><button data-tab="camping" class="hd">Camping</button><button class="x" id="wx" aria-label="Close"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round"><path d="M6 6l12 12M18 6L6 18"/></svg></button></div>
    <div class="body" id="wbody"></div>
    <div class="buyrow"><div class="note" id="wnote">Every job you do pays into this wallet. It's kept for next time, under your crew name.</div><button class="holdbtn" id="wbuy" disabled><div class="fill"></div><span>HOLD TO BUY</span></button></div>
  </div>
</div>
<div id="ghost"><div></div></div>
<div id="rotate">Turn your phone sideways<br><small style="color:#9a978f">the controller works in landscape</small></div>
<div id="gate"><b>POUR DECISIONS</b><span class="go"><span class="first">TAP TO JOIN THE CREW</span><span class="again">TAP TO CARRY ON</span></span><div id="ios"><b>Full screen on iPhone:</b> tap Share, then <b>Add to Home Screen</b>, and open Pour Decisions from your home screen.</div></div>
<button id="fs" aria-label="Full screen"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"><path d="M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5"/></svg></button>
<div id="status">connecting…</div>
<script>
const PORT = __WS_PORT__;
const $ = (id) => document.getElementById(id);
const HAT = '<svg viewBox="0 0 24 20"><path d="M1 16h22v2H1z M3.5 16v-3a8.5 8.5 0 0 1 17 0v3z" fill="currentColor"/></svg>';
// The job icons, as on the TV's hats: the hat in currentColor, the icon on
// the front of the dome (on a dark badge when the hat's in the job colour)
const ICONS = __ICONS__;
const HAT_PATH = '<path d="M1 16h22v2H1z M3.5 16v-3a8.5 8.5 0 0 1 17 0v3z" fill="currentColor"/>';
// (each hat its own mask id: a mask inside a hidden screen draws nothing, so
// two hats can't share one)
let maskN = 0;
function hatInner(role, col, badge) {
  if (!ICONS[role]) return HAT_PATH;
  const id = 'ic' + (++maskN);
  return '<defs><mask id="' + id + '" maskContentUnits="userSpaceOnUse"><image href="' + ICONS[role] + '" x="6.7" y="5.5" width="10.6" height="10.6"/></mask></defs>' + HAT_PATH +
    (badge ? '<circle cx="12" cy="10.8" r="6.2" fill="#0f1b2d"/>' : '') + '<rect x="6.7" y="5.5" width="10.6" height="10.6" fill="' + col + '" mask="url(#' + id + ')"/>';
}
function hat(role, col, badge) { return '<svg viewBox="0 0 24 20">' + hatInner(role, col, badge) + '</svg>'; }
const PIN = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linejoin="round"><path d="M12 22s7-7.2 7-12.5A7 7 0 0 0 5 9.5C5 14.8 12 22 12 22z"/><circle cx="12" cy="9.5" r="2.6"/></svg>';
const LOCK = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" style="width:4vmin;height:4vmin"><rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/></svg>';
// The Site Kit's buttons and buzzes: the same numbers as the TV
const KEY = {A: ['#3fe0c5', '#04281f'], B: ['#ff5a5f', '#2b0606'], X: ['#9b6bff', '#1b0d3a'], Y: ['#ffc23d', '#2a1d00'], stick: ['#3a3d47', '#ffffff']};
const BUZZ = {press: 12, turn: [30, 60, 30], gold: 15, missed: 120, alarm: [90, 60, 90], done: [10, 40, 10]};
const P_COL = ['3d8bff', 'ff4f6d', 'ff8a3d', '7cd992', 'c49bff', '2fd3e8'];
let token = null;
try { token = localStorage.getItem('pd_token'); } catch (e) {}
if (!token) { token = Math.random().toString(36).slice(2, 10); try { localStorage.setItem('pd_token', token); } catch (e) {} }
let ws = null, ready = false, me = {p: 0, pc: '3d8bff'}, screen = '', roster = [], card = null, now = {i: -1}, picked = '', locked = false, nudge = 0;
const status = $('status');
function esc(t) { return String(t).replace(/[&<>]/g, (ch) => ({'&': '&amp;', '<': '&lt;', '>': '&gt;'})[ch]); }
function send(t) { if (ready) ws.send(t); }
let haptics = true;
function buzz(p) { if (haptics && navigator.vibrate) { try { navigator.vibrate(p); } catch (e) {} } }
function connect() {
  ws = new WebSocket('ws://' + location.hostname + ':' + PORT);
  ws.onopen = () => { ready = true; ws.send('hello ' + token); status.textContent = ''; };
  ws.onclose = () => { ready = false; status.textContent = 'reconnecting…'; setTimeout(connect, 1000); };
  ws.onmessage = (ev) => {
    const d = ev.data;
    if (d.startsWith('J ')) { try { onJson(JSON.parse(d.slice(2))); } catch (e) {} return; }
    const m = d.split(' ');
    if (m[0] === 'p') onPlayer(parseInt(m[1]), m[2]);
    else if (m[0] === 'v') buzz((m[1] || '30').split(',').map(Number));
    else if (m[0] === 'full') { status.textContent = 'the crew is full (6 players): watch, or wait for a spot'; }
    else if (m[0] === 'c') onCues(m[1] || '');
  };
}
function onPlayer(p, col) {
  const first = me.p !== p;
  me.p = p; me.pc = col;
  document.documentElement.style.setProperty('--me', '#' + col);
  if (first) showJoined();
}
function showJoined() {
  $('jbig').textContent = 'P' + me.p; $('jbig').style.background = '#' + me.pc;
  $('jk').style.color = '#' + me.pc; $('jt').textContent = 'You are Player ' + me.p;
  $('pdots').innerHTML = P_COL.map((c, i) => {
    const on = roster.some(r => r.p === i + 1) || i + 1 === me.p;
    return '<div style="' + (on ? 'background:#' + c + ';border:0' : '') + (i + 1 === me.p ? ';outline:3px solid #fff;outline-offset:2px' : '') + '">' + (on ? '' : '') + 'P' + (i + 1) + '</div>';
  }).join('');
  $('joined').classList.add('on'); buzz(BUZZ.done);
  setTimeout(() => $('joined').classList.remove('on'), 1800);
}
function onJson(j) {
  if (j.t === 'state') {
    me.name = j.name;
    if (j.s !== screen) { screen = j.s; showScreen(); }
    $('cname').textContent = j.name || '';
    if (j.s === 'sign') { $('sgleft').textContent = j.done ? 'Pressed in. Nice.' : (j.left + ' s left'); signDone = !!j.done; $('slab').classList.toggle('done', signDone); $('sgok').disabled = signDone; $('sgclr').disabled = signDone; }
    if (j.s === 'lobby') { if (!!j.locked !== locked) { locked = !!j.locked; showScreen(); if (locked) buzz(BUZZ.done); } setCount(j.count); }
  } else if (j.t === 'roster') { roster = j.r; drawLobby(); drawSwap(); }
  else if (j.t === 'card') { card = j; drawTicket(); drawLobby(); }
  else if (j.t === 'now') { now = j; drawSteps(); }
  else if (j.t === 'gauge') drawGauge(j);
  else if (j.t === 'nudge') { setNudge(j.lvl); setSpray(j); }
  else if (j.t === 'toast') toast(j.msg);
  else if (j.t === 'dog') drawDog(j);
  else if (j.t === 'wallet') onWallet(j);
  else if (j.t === 'shop') { shop = j; if (walletOpen) drawWallet(); }
  else if (j.t === 'bought') onBought(j);
}
// The dogman: each crane call sits round the stick the way you push for it
let dogLit = '';
function drawDog(j) {
  const z = $('zone');
  z.classList.toggle('dog', !!j.on);
  z.querySelector('.lbl').textContent = j.on ? 'Let go = STOP' : 'Stick';
  if (!j.on) { dogLit = ''; return; }
  j.c.forEach((c, i) => {
    const el = $('call' + i), a = c[1] * Math.PI / 180, r = 25;
    el.textContent = c[0].replace(' ', '\\n');
    el.style.transform = 'translate(calc(-50% + ' + (Math.cos(a) * r).toFixed(1) + 'vmin), calc(-50% + ' + (Math.sin(a) * r).toFixed(1) + 'vmin))';
    el.classList.toggle('lit', c[0] === j.lit);
  });
  if (j.lit && j.lit !== dogLit) buzz(BUZZ.press);
  dogLit = j.lit || '';
}
function showScreen() {
  const lobby = screen === 'lobby';
  const sign = screen === 'sign';
  $('lobby').classList.toggle('on', lobby && !locked);
  $('locked').classList.toggle('on', lobby && locked);
  $('play').classList.toggle('on', !lobby && !sign);
  $('sign').classList.toggle('on', sign);
  if (sign) startSign();
  if (!lobby) closeSwap();
  showWalletBtn();
  drawTicket();
}
let toastT = null;
function toast(msg) { const t = $('toast'); t.textContent = msg; t.classList.add('on'); clearTimeout(toastT); toastT = setTimeout(() => t.classList.remove('on'), 2200); buzz(BUZZ.missed); }
// ---------------------------------------------------------------- the ticket
function chip(k) { const c = KEY[k] || KEY.stick; return '<span class="k" style="background:' + c[0] + ';color:' + c[1] + '">' + (k === 'stick' ? 'STICK' : k) + '</span>'; }
function mine() { return roster.find(r => r.p === me.p); }
function drawTicket() {
  if (!card) return;
  const col = '#' + card.col;
  document.documentElement.style.setProperty('--job', col);
  if ($('thhat').dataset.role !== card.role) { $('thhat').dataset.role = card.role; $('thhat').innerHTML = hatInner(card.role, col, false); }
  const t = $('ticket');
  let name = card.name, goal = card.goal, foot = '';
  t.classList.toggle('pump', card.role === 'pump' && screen === 'play' && !now.climb);
  if (screen === 'site') { $('tk').textContent = 'P' + me.p + ' · NEXT UP'; name = 'Pick the site'; goal = 'The first player picks the site and the kit on the TV: stick to choose, A to start, B back to the crew.'; }
  else if (screen === 'pause') { $('tk').textContent = 'P' + me.p + ' · SMOKO'; name = 'Paused'; goal = 'Steer the menu on the TV: stick up and down, A to choose, B to get back to work.'; }
  else { $('tk').textContent = 'P' + me.p + ' · YOUR JOB'; foot = (card.watch ? '<b>Watch for:</b> ' + esc(card.watch) + ' ' : '') + esc(card.climb || ''); }
  $('tn').textContent = name;
  $('goal').textContent = goal;
  $('tfoot').innerHTML = foot;
  $('tsw').style.display = screen === 'play' ? 'flex' : 'none';
  drawSteps();
}
let lastStep = -1, lastGo = '';
function drawSteps() {
  if (!card) return;
  const el = $('steps');
  if (screen !== 'play') { el.innerHTML = ''; return; }
  const steps = now.climb && card.climbsteps.length ? card.climbsteps : card.steps;
  const pump = $('ticket').classList.contains('pump');
  let html = '';
  steps.forEach((s, i) => {
    const on = i === now.i;
    if (pump && now.i >= 0 && !on && i !== now.i + 1) return;
    html += '<div class="st' + (on ? ' now' : '') + '">' + chip(s[0]) + '<span>' + esc(s[1]) + (on && now.verb ? '<span class="v">Now: ' + esc(now.verb) + '</span>' : '') + '</span></div>';
  });
  if (now.i < 0 && now.verb) html = '<div class="st now">' + chip(now.btn || 'A') + '<span>' + esc(now.verb) + '</span></div>' + (pump ? '' : html);
  // Nothing to press yet, but the job wants you somewhere: say where
  if (now.go) html = '<div class="st go">' + PIN + '<span>' + esc(now.go) + '</span></div>' + html;
  // The toolbox talk's up on the TV: hold A here to start, the same as there
  if (now.brief >= 0) html = '<div class="st now brief"><div style="display:flex;gap:1.8vmin;align-items:center">' + chip('A') + '<span>Hold A to start the pour</span></div><div class="bar"><i style="width:' + Math.round(now.brief * 100) + '%"></i></div><span class="v" style="color:#5f5a4c">Toolbox talk on the TV. Anyone holding A starts it.</span></div>';
  el.innerHTML = html;
  if (now.go && now.go !== lastGo) buzz(BUZZ.turn);
  lastGo = now.go || '';
  if (now.i !== lastStep && now.i >= 0) buzz(BUZZ.press);
  lastStep = now.i;
}
// The pump gauge, the same dial and bands as the TV (green, amber, red)
(function () {
  const arc = (a0, a1) => { const p = (a) => [50 - 42 * Math.cos(a), 50 - 42 * Math.sin(a)]; const s = p(a0), e = p(a1); return 'M' + s[0] + ' ' + s[1] + ' A42 42 0 0 1 ' + e[0] + ' ' + e[1]; };
  const M = 250, f = (b) => Math.PI * b / M;
  $('g1').setAttribute('d', arc(f(0), f(120))); $('g1').setAttribute('stroke', '#4fb36b');
  $('g2').setAttribute('d', arc(f(120), f(180))); $('g2').setAttribute('stroke', '#f2b51f');
  $('g3').setAttribute('d', arc(f(180), f(250))); $('g3').setAttribute('stroke', '#ff3b2f');
})();
let wasSpike = false;
function drawGauge(g) {
  const v = Math.max(0, Math.min(1, g.bar / 250));
  $('needle').style.transform = 'rotate(' + (-90 + 180 * v) + 'deg)';
  const r = $('gread');
  r.textContent = g.spike ? 'SPIKE: KILL IT' : (g.tripped ? 'OFF · RESTART' : (g.warn ? 'WATCH IT…' : g.bar + ' bar'));
  r.style.color = g.spike ? '#ff3b2f' : (g.tripped ? '#b17a00' : (g.warn ? '#b17a00' : '#2a7a3e'));
  if (g.spike && !wasSpike) buzz(BUZZ.alarm);
  wasSpike = g.spike;
}
// ---------------------------------------------------------------- nudges
function setNudge(l) {
  if (l === nudge) return;
  if (l >= 1 && nudge < 1) buzz(BUZZ.turn);
  nudge = l;
  $('edge').classList.toggle('on', l >= 1 && screen === 'play');
  $('helping').classList.toggle('on', l >= 3);
  placeGhost();
}
// The leading hand covering: his spray on the phone too, bleeped
const SPRAY = ['OI! WAKE UP, YA #@%&!', 'WHAT THE $#!@ ARE YA DOIN\'?!', 'MOVE YA %&#@ FEET!', 'MY NAN POURS FASTER, YA #@%&!', 'FAIR #%@& DINKUM!'];
let sprayOn = false;
function setSpray(j) {
  const on = j.lvl >= 3;
  if (on && !sprayOn) {
    const h = $('helping');
    h.querySelector('b').textContent = (j.lh || 'MACCA').toUpperCase() + ': ' + SPRAY[Math.floor(Math.random() * SPRAY.length)];
    h.querySelector('span').textContent = j.firm ? 'He\'s doing this one. Watch where you go: that\'s the job.' : 'He\'s doing this step. Press anything to take it back.';
    buzz([60, 40, 60, 40, 120]);
  }
  sprayOn = on;
}
function placeGhost() {
  const g = $('ghost');
  const b = document.querySelector('.btn.cue');
  if (nudge >= 2 && nudge < 3 && b && screen === 'play') {
    const r = b.getBoundingClientRect();
    g.style.left = (r.left + r.width / 2 - g.offsetWidth * 0.3) + 'px'; g.style.top = (r.top + r.height / 2 - g.offsetHeight * 0.25) + 'px';
    g.classList.add('on');
  } else g.classList.remove('on');
}
// ---------------------------------------------------------------- button cues
let anyAlarm = false;
function onCues(s) {
  const want = {};
  s.split(',').forEach(x => { if (x) { const f = x.split(':'); want[f[0]] = {verb: (f[1] || '').replace(/_/g, ' '), p: parseFloat(f[2] || '-1'), urgent: f[3] === '1', gold: parseFloat(f[4] || '0'), alarm: f[5] === '1'}; } });
  let alarm = false;
  ['A', 'B', 'X', 'Y'].forEach(b => {
    const el = $(b), w = want[b];
    el.classList.toggle('cue', !!w);
    el.classList.toggle('urgent', !!(w && w.urgent));
    const wasAlarm = el.classList.contains('alarm');
    el.classList.toggle('alarm', !!(w && w.alarm));
    if (w && w.alarm && !wasAlarm) buzz(BUZZ.alarm);
    alarm = alarm || !!(w && w.alarm);
    el.classList.toggle('hold', !!(w && w.p >= 0));
    // (gold is a spectrum: full sparkle for someone new to the job, fading
    // to a plain gold face, then just the button, as they get good)
    const gl = w ? (w.gold || 0) : 0, g = gl > 0.05;
    if (g && !el.classList.contains('gold')) { if (gl > 0.3) stars(el, Math.round(14 * gl)); if (gl > 0.2) buzz(BUZZ.gold); }
    el.classList.toggle('gold', g);
    el.classList.toggle('faint', g && gl < 0.45);
    el.style.setProperty('--gl', gl.toFixed(2));
    el.dataset.gl = gl.toFixed(2);
    el.style.setProperty('--p', w && w.p >= 0 ? Math.min(1, w.p) : 0);
    el.querySelector('.wet').style.height = (w && w.p >= 0 ? Math.min(1, w.p) * 100 : 0) + '%';
    if (w) el.querySelector('.verb b').textContent = w.verb || b;
    el.querySelector('.verb').style.display = w && w.verb ? 'flex' : 'none';
    if (w && w.p >= 0.99 && !el.dataset.done) { el.dataset.done = '1'; stars(el, 20); buzz(BUZZ.done); }
    if (!w || w.p < 0.5) delete el.dataset.done;
  });
  if (alarm !== anyAlarm) { anyAlarm = alarm; $('edge').classList.toggle('alarm', alarm); }
  placeGhost();
}
// ---------------------------------------------------------------- star sparks
const fx = $('fx'), g = fx.getContext('2d');
let parts = [], dpr = 1;
function resize() { dpr = Math.min(2, window.devicePixelRatio || 1); fx.width = innerWidth * dpr; fx.height = innerHeight * dpr; }
addEventListener('resize', () => { resize(); placeGhost(); }); resize();
function stars(el, n) {
  const r = el.getBoundingClientRect(), cx = r.left + r.width / 2, cy = r.top + r.height / 2;
  for (let i = 0; i < n; i++) {
    const a = Math.random() * Math.PI * 2, sp = 180 + Math.random() * 300;
    parts.push({x: cx + Math.cos(a) * r.width * .45, y: cy + Math.sin(a) * r.width * .45, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp - 80, life: 0, max: .45 + Math.random() * .3, size: 5 + Math.random() * 5, rot: Math.random() * 6});
  }
}
setInterval(() => {
  document.querySelectorAll('.btn.gold').forEach(el => {
    if (Math.random() > parseFloat(el.dataset.gl || '1') * 1.3 - 0.3) return;
    const r = el.getBoundingClientRect(), a = Math.random() * Math.PI * 2;
    parts.push({x: r.left + r.width / 2 + Math.cos(a) * r.width * .55, y: r.top + r.height / 2 + Math.sin(a) * r.width * .55, vx: Math.cos(a) * 50, vy: -70 - Math.random() * 50, life: 0, max: .5, size: 5, rot: 0});
  });
}, 100);
let last = performance.now();
function frame(t) {
  const dt = Math.min(.05, (t - last) / 1000); last = t;
  g.setTransform(dpr, 0, 0, dpr, 0, 0);
  g.clearRect(0, 0, innerWidth, innerHeight);
  parts = parts.filter(q => (q.life += dt) < q.max);
  for (const q of parts) {
    q.vx *= 1 - 3 * dt; q.vy = q.vy * (1 - 3 * dt) + 400 * dt;
    q.x += q.vx * dt; q.y += q.vy * dt; q.rot += dt * 6;
    const k = 1 - q.life / q.max, r = q.size * (.4 + .6 * k);
    g.globalAlpha = k; g.fillStyle = '#ffd23f';
    g.beginPath();
    for (let i = 0; i < 8; i++) { const a = q.rot + Math.PI / 4 * i, rr = i % 2 ? r * .32 : r; g.lineTo(q.x + Math.cos(a) * rr, q.y + Math.sin(a) * rr); }
    g.closePath(); g.fill();
  }
  g.globalAlpha = 1;
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);
// ---------------------------------------------------------------- buttons
['A', 'B', 'X', 'Y'].forEach(b => {
  const el = $(b);
  const down = (e) => {
    e.preventDefault();
    try { el.setPointerCapture(e.pointerId); } catch (err) {}
    if (el.classList.contains('down')) return;
    el.classList.remove('boing'); el.classList.add('down');
    send('d ' + b);
    buzz(BUZZ.press);
  };
  const up = () => {
    if (!el.classList.contains('down')) return;
    el.classList.remove('down');
    void el.offsetWidth; el.classList.add('boing');
    send('u ' + b);
  };
  el.addEventListener('pointerdown', down);
  el.addEventListener('pointerup', up);
  el.addEventListener('pointercancel', up);
  el.addEventListener('lostpointercapture', up);
  el.addEventListener('animationend', (e) => { if (e.animationName === 'boing') el.classList.remove('boing'); });
});
document.querySelectorAll('.pausebtn').forEach(pb => {
  pb.addEventListener('pointerdown', (e) => { e.preventDefault(); pb.classList.add('down'); send('d MENU'); buzz(BUZZ.press); });
  pb.addEventListener('pointerup', () => pb.classList.remove('down'));
});
// ---------------------------------------------------------------- the stick: only inside its zone, so it never covers the ticket
const zone = $('zone'), base = $('base'), knob = $('knob'), wedge = $('wedge');
let sid = null, ox = 0, oy = 0, lastSend = 0, vx = 0, vy = 0, atEdge = false, stickTimer = null;
function radius() { return base.getBoundingClientRect().width / 2; }
function setKnob(dx, dy) { knob.style.transform = 'translate(calc(-50% + ' + dx + 'px), calc(-50% + ' + dy + 'px))'; }
function sendStick(force) {
  const t = performance.now();
  if (force || t - lastSend > 33) {
    lastSend = t;
    if (stickTimer) { clearTimeout(stickTimer); stickTimer = null; }
    send('m ' + vx.toFixed(2) + ' ' + vy.toFixed(2));
  } else if (!stickTimer) {
    // (the last position always gets there, so the boom stops where your thumb stopped)
    stickTimer = setTimeout(() => { stickTimer = null; sendStick(true); }, 34 - (t - lastSend));
  }
}
zone.addEventListener('pointerdown', (e) => {
  if (swapOpen || walletOpen) return;
  e.preventDefault(); sid = e.pointerId; zone.setPointerCapture(sid);
  const r = zone.getBoundingClientRect(), R = radius();
  // Centre the stick under the thumb, kept inside the zone
  ox = Math.max(r.left + R * .6, Math.min(r.right - R * .6, e.clientX));
  oy = Math.max(r.top + R * .6, Math.min(r.bottom - R * .6, e.clientY));
  base.style.left = (ox - r.left) + 'px'; base.style.top = (oy - r.top) + 'px';
  base.classList.add('on');
  moveStick(e);
});
function moveStick(e) {
  const R = radius();
  let dx = e.clientX - ox, dy = e.clientY - oy;
  const d = Math.hypot(dx, dy);
  if (d > R) { dx *= R / d; dy *= R / d; }
  setKnob(dx, dy);
  vx = dx / R; vy = dy / R;
  const mag = Math.min(1, d / R);
  wedge.style.opacity = mag;
  wedge.style.transform = 'rotate(' + (Math.atan2(dy, dx) * 180 / Math.PI + 90) + 'deg)';
  if (mag >= 1 && !atEdge) { atEdge = true; buzz(5); }
  if (mag < .9) atEdge = false;
  sendStick(false);
}
zone.addEventListener('pointermove', (e) => { if (e.pointerId === sid) moveStick(e); });
function endStick(e) {
  if (e && e.pointerId !== sid) return;
  sid = null; vx = 0; vy = 0; setKnob(0, 0); sendStick(true);
  base.style.left = '50%'; base.style.top = '50%';
  base.classList.remove('on'); wedge.style.opacity = 0;
}
zone.addEventListener('pointerup', endStick);
zone.addEventListener('pointercancel', endStick);
// ---------------------------------------------------------------- hold-to-confirm buttons: fill with concrete, then set
function holdButton(el, ms, done) {
  let t0 = 0, raf = 0;
  const fill = el.querySelector('.fill');
  const tick = () => {
    const k = Math.min(1, (performance.now() - t0) / ms);
    if (fill) fill.style.width = (k * 100) + '%';
    if (k >= 1) { stop(false); stars(el, 16); buzz(BUZZ.done); done(); return; }
    raf = requestAnimationFrame(tick);
  };
  const stop = (reset) => { cancelAnimationFrame(raf); t0 = 0; el.classList.remove('down'); if (fill && reset !== false) fill.style.width = '0'; };
  el.addEventListener('pointerdown', (e) => { e.preventDefault(); if (el.disabled) return; try { el.setPointerCapture(e.pointerId); } catch (err) {} t0 = performance.now(); el.classList.add('down'); buzz(BUZZ.press); tick(); });
  el.addEventListener('pointerup', () => stop());
  el.addEventListener('pointercancel', () => stop());
}
// ---------------------------------------------------------------- lobby
function jobCard(r, cls, extra) {
  return '<button class="job ' + cls + '" data-id="' + r.id + '" style="--c:#' + r.col + '"><span class="n"><span class="sq">' + hat(r.id, '#' + r.col, false) + '</span>' + esc(r.name) + extra + '</span>' +
    (r.ask ? '<span class="q">' + esc(r.ask) + '</span>' : '') + '<span class="w">' + esc(r.line) + '</span></button>';
}
function drawLobby() {
  if (!roster.length) return;
  $('lp').textContent = 'P' + me.p; $('lp').style.background = '#' + me.pc;
  const people = roster.filter(r => r.p > 0), lockedN = people.filter(r => r.lock).length;
  $('lsub').textContent = lockedN + ' of ' + people.length + ' locked · bots take the rest';
  $('ljobs').innerHTML = roster.map(r => {
    if (r.p === me.p) return jobCard(r, 'mine', '<span class="ptag" style="background:#' + r.pc + '">P' + r.p + '</span>');
    if (r.p > 0) return jobCard(r, 'taken', '<span class="ptag" style="background:#' + r.pc + '">P' + r.p + (r.lock ? ' ' + LOCK : '') + '</span>');
    return jobCard(r, '', '');
  }).join('');
  const m = mine();
  if (m) { $('ln').textContent = m.name; document.documentElement.style.setProperty('--job', '#' + m.col); $('lhat').innerHTML = hatInner(m.id, '#' + m.col, true); }
  $('lk').textContent = 'P' + me.p + ' · LOCKED IN';
  $('crewlist').innerHTML = roster.map(r => '<div class="cl' + (r.p === me.p ? ' me' : (r.p ? '' : ' bot')) + '"><i style="background:#' + r.col + '"></i><span>' + esc(r.name) + '</span>' + (r.p ? '<span class="ptag" style="background:#' + r.pc + '">P' + r.p + (r.p === me.p ? ' · you' : '') + '</span>' : '<span style="font-size:3vmin;flex-grow:0">bot · ' + esc(r.who) + '</span>') + '</div>').join('');
}
$('ljobs').addEventListener('pointerdown', (e) => {
  const b = e.target.closest('.job'); if (!b || b.classList.contains('taken')) { if (b) buzz(BUZZ.missed); return; }
  send('pick ' + b.dataset.id); buzz(BUZZ.press);
});
holdButton($('lockgo'), 800, () => send('lock'));
$('unlock').addEventListener('pointerdown', (e) => { e.preventDefault(); send('unlock'); buzz(BUZZ.press); });
$('cprev').addEventListener('pointerdown', (e) => { e.preventDefault(); send('char -1'); buzz(BUZZ.press); });
$('cnext').addEventListener('pointerdown', (e) => { e.preventDefault(); send('char 1'); buzz(BUZZ.press); });
function setCount(c) {
  $('count').textContent = c > 0 ? c : '';
  $('cnote').textContent = c > 0 ? 'Everyone’s in. Starting the pour. Once you’re on site you can swap to any job a bot is doing.' : 'Waiting for the rest of the crew to lock in. Once you’re on site you can swap to any job a bot is doing.';
}
// ---------------------------------------------------------------- swap jobs on site
let swapOpen = false, swapPick = '';
$('thead').addEventListener('pointerdown', (e) => { e.preventDefault(); if (screen === 'play') openSwap(); });
$('swapx').addEventListener('pointerdown', (e) => { e.preventDefault(); closeSwap(); });
function openSwap() { swapOpen = true; swapPick = ''; endStick(); $('swap').classList.add('on'); $('zone').classList.add('off'); drawSwap(); buzz(BUZZ.press); }
function closeSwap() { swapOpen = false; $('swap').classList.remove('on'); $('zone').classList.remove('off'); }
function drawSwap() {
  if (!swapOpen) return;
  $('jobs').innerHTML = roster.map(r => {
    if (r.p === me.p) return '<div class="job mine" style="--c:#' + r.col + '"><span class="n">' + hat(r.id, '#' + r.col, true) + esc(r.name) + '</span><span class="w">you, P' + r.p + '</span></div>';
    if (r.p > 0) return '<div class="job taken" style="--c:#' + r.col + '"><span class="n">' + LOCK + esc(r.name) + '<span class="ptag" style="background:#' + r.pc + '">P' + r.p + '</span></span><span class="w">' + esc(r.who) + '</span></div>';
    return '<button class="job' + (r.id === swapPick ? ' pick' : '') + '" data-id="' + r.id + '" style="--c:#' + r.col + '"><span class="n">' + hat(r.id, '#' + r.col, true) + esc(r.name) + '</span><span class="w">bot ' + esc(r.who) + ' · ' + esc(r.line) + '</span></button>';
  }).join('');
  const free = roster.filter(r => !r.p).length;
  $('swapgo').disabled = !swapPick;
  $('swapnote').textContent = free ? 'Tap a job a bot’s doing, then hold to swap. Your chibi stands still while this is open.' : 'Every job has a player on it right now.';
}
$('jobs').addEventListener('pointerdown', (e) => { const b = e.target.closest('button.job'); if (!b) return; swapPick = b.dataset.id; drawSwap(); buzz(BUZZ.press); });
holdButton($('swapgo'), 700, () => { if (swapPick) send('swap ' + swapPick); closeSwap(); });
// ---------------------------------------------------------------- sign the slab
// The square on the phone is the player's square in the slab: points go to
// the game 0..1 across it, a few a second, and it draws the grooves.
let signDone = false, inkLast = null, inkSent = 0;
const slab = $('slab'), sctx = slab.getContext('2d');
function startSign() {
  const r = slab.getBoundingClientRect(), d = Math.min(2, window.devicePixelRatio || 1);
  slab.width = r.width * d; slab.height = r.height * d;
  sctx.clearRect(0, 0, slab.width, slab.height);
  signDone = false; inkLast = null; buzz(BUZZ.turn);
}
function inkAt(e) { const r = slab.getBoundingClientRect(); return [Math.max(0, Math.min(1, (e.clientX - r.left) / r.width)), Math.max(0, Math.min(1, (e.clientY - r.top) / r.height))]; }
function inkLine(a, b) {
  const w = slab.width;
  sctx.lineCap = 'round'; sctx.lineJoin = 'round';
  sctx.strokeStyle = 'rgba(205,199,188,.9)'; sctx.lineWidth = w * 0.05;
  sctx.beginPath(); sctx.moveTo(a[0] * w + w * 0.006, a[1] * w + w * 0.006); sctx.lineTo(b[0] * w + w * 0.006, b[1] * w + w * 0.006); sctx.stroke();
  sctx.strokeStyle = 'rgba(92,87,79,.95)'; sctx.lineWidth = w * 0.04;
  sctx.beginPath(); sctx.moveTo(a[0] * w, a[1] * w); sctx.lineTo(b[0] * w, b[1] * w); sctx.stroke();
}
slab.addEventListener('pointerdown', (e) => { if (signDone) return; e.preventDefault(); slab.setPointerCapture(e.pointerId); inkLast = inkAt(e); inkLine(inkLast, inkLast); send('ink ' + inkLast[0].toFixed(3) + ' ' + inkLast[1].toFixed(3)); buzz(BUZZ.press); });
slab.addEventListener('pointermove', (e) => {
  if (signDone || !inkLast) return;
  const p = inkAt(e);
  if (Math.hypot(p[0] - inkLast[0], p[1] - inkLast[1]) < 0.012) return;
  inkLine(inkLast, p); inkLast = p;
  const t = performance.now();
  if (t - inkSent > 25) { inkSent = t; send('ink ' + p[0].toFixed(3) + ' ' + p[1].toFixed(3)); }
});
function inkUp() { if (inkLast) { send('ink ' + inkLast[0].toFixed(3) + ' ' + inkLast[1].toFixed(3)); send('inkup'); } inkLast = null; }
slab.addEventListener('pointerup', inkUp);
slab.addEventListener('pointercancel', inkUp);
$('sgclr').addEventListener('click', () => { if (signDone) return; sctx.clearRect(0, 0, slab.width, slab.height); send('inkclr'); buzz(BUZZ.press); });
$('sgok').addEventListener('click', () => { if (signDone) return; send('inkok'); signDone = true; buzz(BUZZ.done); });

// ---------------------------------------------------------------- full screen and the first tap
const de = document.documentElement;
const standalone = (window.navigator.standalone === true) || matchMedia('(display-mode: fullscreen), (display-mode: standalone)').matches;
const canFs = !!(de.requestFullscreen || de.webkitRequestFullscreen);
const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
if (isIOS && !standalone) $('ios').style.display = 'block';
function goFull() {
  if (standalone) return;
  const f = de.requestFullscreen || de.webkitRequestFullscreen;
  if (f) { try { const r = f.call(de, {navigationUI: 'hide'}); if (r && r.catch) r.catch(() => {}); } catch (e) {} }
  const so = window.screen.orientation; if (so && so.lock) so.lock('landscape').catch(() => {});
}
const fsBtn = $('fs');
function fsShow() { fsBtn.style.display = (canFs && !isIOS && !standalone && !(document.fullscreenElement || document.webkitFullscreenElement)) ? 'flex' : 'none'; }
document.addEventListener('fullscreenchange', fsShow);
document.addEventListener('webkitfullscreenchange', fsShow);
fsBtn.addEventListener('pointerdown', (e) => { e.preventDefault(); goFull(); });
// ---------------------------------------------------------------- keeping the phone awake
// The Wake Lock API only works on https pages, and the game serves this page
// over plain http on the home Wi-Fi, so it falls back to what NoSleep.js
// does: a tiny silent video playing on a loop, out of sight, which phones
// treat as "something's playing" and don't dim the screen for.
let lock = null;
const awake = document.createElement('video');
awake.setAttribute('playsinline', ''); awake.setAttribute('muted', ''); awake.muted = true; awake.loop = true;
awake.setAttribute('title', 'Keeping the screen on');
awake.style.cssText = 'position:fixed;left:0;top:0;width:2px;height:2px;opacity:0.01;pointer-events:none;z-index:-1';
for (const [t, d] of [['video/mp4', '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ACFoZGxyAAAAAAAAAABtZGlyYXBwbAAAAAAAAAAAAAAAAC1pbHN0AAAAJal0b28AAAAdZGF0YQAAAAEAAAAATGF2ZjYwLjE2LjEwMAAAAAhmcmVlAAAEPm1kYXTeAgBMYXZjNjAuMzEuMTAyAAIwQA4AAAJyBgX//27cRem95tlIt5Ys2CDZI+7veDI2NCAtIGNvcmUgMTY0IHIzMTA4IDMxZTE5ZjkgLSBILjI2NC9NUEVHLTQgQVZDIGNvZGVjIC0gQ29weWxlZnQgMjAwMy0yMDIzIC0gaHR0cDovL3d3dy52aWRlb2xhbi5vcmcveDI2NC5odG1sIC0gb3B0aW9uczogY2FiYWM9MCByZWY9MyBkZWJsb2NrPTE6LTM6LTMgYW5hbHlzZT0weDE6MHgxMTEgbWU9aGV4IHN1Ym1lPTcgcHN5PTEgcHN5X3JkPTIuMDA6MC43MCBtaXhlZF9yZWY9MSBtZV9yYW5nZT0xNiBjaHJvbWFfbWU9MSB0cmVsbGlzPTEgOHg4ZGN0PTAgY3FtPTAgZGVhZHpvbmU9MjEsMTEgZmFzdF9wc2tpcD0xIGNocm9tYV9xcF9vZmZzZXQ9LTQgdGhyZWFkcz0xIGxvb2thaGVhZF90aHJlYWRzPTEgc2xpY2VkX3RocmVhZHM9MCBucj0wIGRlY2ltYXRlPTEgaW50ZXJsYWNlZD0wIGJsdXJheV9jb21wYXQ9MCBjb25zdHJhaW5lZF9pbnRyYT0wIGJmcmFtZXM9MCB3ZWlnaHRwPTAga2V5aW50PTI1MCBrZXlpbnRfbWluPTEgc2NlbmVjdXQ9NDAgaW50cmFfcmVmcmVzaD0wIHJjX2xvb2thaGVhZD00MCByYz1jcmYgbWJ0cmVlPTEgY3JmPTIzLjAgcWNvbXA9MC42MCBxcG1pbj0wIHFwbWF4PTY5IHFwc3RlcD00IGlwX3JhdGlvPTEuNDAgYXE9MToxLjIwAIAAAAAPZYiEBfOf//8PRQABV5+AARggBwEYIAcBGCAHARggBwEYIAcBGCAHARggBwEYIAcAAAAHQZo4C+c6gAEYIAcBGCAHARggBwEYIAcBGCAHARggBwEYIAcBGCAHAAAAB0GaVAL5zqABGCAHARggBwEYIAcBGCAHARggBwEYIAcBGCAHARggBwAAAAZBmmAXznUBGCAHARggBwEYIAcBGCAHARggBwEYIAcBGCAHARggBwAAAAZBmoAXznUBGCAHARggBwEYIAcBGCAHARggBwEYIAcBGCAHARggBwAAAAZBmqAXznUBGCAHARggBwEYIAcBGCAHARggBwEYIAcBGCAHAAAABkGawBfOdQEYIAcBGCAHARggBwEYIAcBGCAHARggBwEYIAcBGCAHAAAABkGa4BfOdQEYIAcBGCAHARggBwEYIAcBGCAHARggBwEYIAcBGCAHAAAABkGbABfOdQEYIAcBGCAHARggBwEYIAcBGCAHARggBwEYIAcBGCAHAAAABkGbIBfOdQEYIAcBGCAHARggBwEYIAcBGCAHARggBwEYIAcBGCAH'], ['video/webm', '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']]) { const so = document.createElement('source'); so.type = t; so.src = 'data:' + t + ';base64,' + d; awake.appendChild(so); }
document.body.appendChild(awake);
function keepAwake() {
  if ('wakeLock' in navigator && window.isSecureContext) {
    if (!lock) navigator.wakeLock.request('screen').then((l) => { lock = l; l.addEventListener('release', () => { lock = null; }); }).catch(() => {});
    return;
  }
  const r = awake.play(); if (r && r.catch) r.catch(() => {});
}
// Coming back to the page (after the phone locked, or a swipe away): the
// screen's on again, so get back in with one tap, full screen and sideways
function welcomeBack() {
  if (document.visibilityState !== 'visible') return;
  keepAwake();
  const full = standalone || isIOS || !canFs || document.fullscreenElement || document.webkitFullscreenElement;
  if (!full && $('gate').dataset.done) { $('gate').classList.add('back'); $('gate').style.display = 'flex'; }
}
document.addEventListener('visibilitychange', welcomeBack);
document.addEventListener('fullscreenchange', () => { if (!(document.fullscreenElement || document.webkitFullscreenElement)) setTimeout(welcomeBack, 300); });
// Any touch at all re-arms it (a phone may stop a video it decides is idle)
document.addEventListener('pointerdown', keepAwake, {passive: true});
$('gate').addEventListener('pointerdown', () => { $('gate').style.display = 'none'; $('gate').dataset.done = '1'; goFull(); keepAwake(); setTimeout(fsShow, 400); });
if (location.search.includes('nogate')) { $('gate').style.display = 'none'; $('gate').dataset.done = '1'; }
// ---------------------------------------------------------------- no zooming (iPhone)
// Safari on iOS ignores "user-scalable=no", so two thumbs on the screen at
// once (the stick and a button) read as a pinch, and a quick double press
// as a double-tap zoom: either zooms the controller off the edge. Block
// both, and if the page ever does end up zoomed, snap it back.
const vpMeta = document.querySelector('meta[name=viewport]');
for (const ev of ['gesturestart', 'gesturechange', 'gestureend']) document.addEventListener(ev, (e) => e.preventDefault(), {passive: false});
document.addEventListener('dblclick', (e) => e.preventDefault(), {passive: false});
let lastTouchEnd = 0;
document.addEventListener('touchend', (e) => { const now = Date.now(); if (now - lastTouchEnd < 350 && e.cancelable) e.preventDefault(); lastTouchEnd = now; }, {passive: false});
document.addEventListener('touchmove', (e) => { if ((e.scale !== undefined && e.scale !== 1) && e.cancelable) e.preventDefault(); }, {passive: false});
let zoomedAt = 0;
function unzoom() {
  const vv = window.visualViewport;
  if (!vv || vv.scale <= 1.01) { zoomedAt = 0; return; }
  // Still stuck after a few tries: reload. The page keeps its player token,
  // so it rejoins as the same player on the same chibi.
  if (!zoomedAt) zoomedAt = Date.now();
  else if (Date.now() - zoomedAt > 2500) { zoomedAt = 0; location.reload(); return; }
  // (re-setting the viewport tag makes Safari drop back to 1x)
  const c = vpMeta.getAttribute('content');
  vpMeta.setAttribute('content', c.replace('maximum-scale=1', 'maximum-scale=1.01'));
  setTimeout(() => { vpMeta.setAttribute('content', c); window.scrollTo(0, 0); }, 50);
}
if (window.visualViewport) { visualViewport.addEventListener('resize', unzoom); visualViewport.addEventListener('scroll', unzoom); }
setInterval(unzoom, 1000);
// ---------------------------------------------------------------- the wallet and the ute shop
let wal = {cash: 0, pour: 0, banked: 0, utes: [], ute: '', kit: [], name: ''}, shop = {utes: [], kit: []};
let walletOpen = false, wTab = 'garage', wPick = '';
const money = (n) => (n < 0 ? '-$' : '$') + Math.abs(n).toLocaleString('en-AU');
function onWallet(j) {
  const more = j.cash > wal.cash;
  wal = j;
  $('wbal').textContent = money(j.cash);
  if (more) { const b = $('walletbtn'); b.classList.remove('bump'); void b.offsetWidth; b.classList.add('bump'); }
  if (walletOpen) drawWallet();
}
function openWallet() { walletOpen = true; wPick = ''; endStick(); closeSwap(); $('wallet').classList.add('on'); send('wallet 1'); drawWallet(); buzz(BUZZ.press); }
function closeWallet() { walletOpen = false; $('wallet').classList.remove('on'); send('wallet 0'); }
$('walletbtn').addEventListener('pointerdown', (e) => { e.preventDefault(); walletOpen ? closeWallet() : openWallet(); });
$('wx').addEventListener('pointerdown', (e) => { e.preventDefault(); closeWallet(); });
document.querySelectorAll('#wallet .tabs button[data-tab]').forEach(b => b.addEventListener('pointerdown', (e) => { e.preventDefault(); wTab = b.dataset.tab; wPick = ''; drawWallet(); buzz(BUZZ.press); }));
// A side-on ute, with the kit that's fitted
function uteSvg(id, kit) {
  const u = shop.utes.find(x => x.id === id) || {col: 'cfcfcf'}, has = (k) => kit.includes(k);
  const lift = has('lift') ? 7 : 0, r = has('mudtyres') ? 21 : 17, gy = 124, d = -lift - (r - 17);
  const col = '#' + u.col, dark = '#2a2d33';
  let s = '<svg viewBox="0 0 300 130">';
  s += '<path d="M0 ' + (gy + 1) + ' h300" stroke="#3a3d47" stroke-width="2"/>';
  const wheel = (x) => '<circle cx="' + x + '" cy="' + (gy - r) + '" r="' + r + '" fill="#16171a"/>' + (has('mudtyres') ? '<circle cx="' + x + '" cy="' + (gy - r) + '" r="' + r + '" fill="none" stroke="#3b3d42" stroke-width="5" stroke-dasharray="3 3"/>' : '') + '<circle cx="' + x + '" cy="' + (gy - r) + '" r="' + (r * 0.5) + '" fill="#8b9097"/>';
  s += '<g transform="translate(0 ' + d + ')">';
  if (has('canopy')) s += '<rect x="190" y="38" width="88" height="30" rx="3" fill="#c9ced3" stroke="#8b9097"/><rect x="198" y="44" width="72" height="14" rx="2" fill="#3c4a57"/>';
  else {
    if (has('drawers')) s += '<rect x="196" y="58" width="78" height="9" fill="#555b62"/>';
    const lift2 = has('drawers') ? 9 : 0;
    if (has('fridge')) s += '<rect x="198" y="' + (52 - lift2) + '" width="24" height="16" rx="2" fill="#5d7f9e"/>';
    if (has('jerrycans')) s += '<rect x="226" y="' + (54 - lift2) + '" width="10" height="14" rx="1" fill="#c8372d"/><rect x="238" y="' + (54 - lift2) + '" width="10" height="14" rx="1" fill="#3c7a3a"/>';
    if (has('swag')) s += '<rect x="250" y="' + (58 - lift2) + '" width="26" height="10" rx="5" fill="#5f6b3a"/>';
  }
  s += '<path d="M22 96 L24 75 Q26 68 40 67 L106 64 L128 40 L188 40 L192 66 L280 66 L282 96 Z" fill="' + col + '" stroke="#1b1c20" stroke-width="2"/>';
  s += '<path d="M113 64 L131 45 L156 45 L156 64 Z M160 64 L160 45 L183 45 L186 64 Z" fill="#2f3a44"/>';
  s += '<path d="M22 86 h260" stroke="rgba(0,0,0,.18)" stroke-width="3"/>';
  if (has('bullbar')) s += '<path d="M10 98 V64 H26 M10 72 H26 M10 82 H26 M18 64 V98" fill="none" stroke="#2a2d33" stroke-width="4" stroke-linejoin="round"/>';
  if (has('winch')) s += '<rect x="11" y="86" width="13" height="8" rx="2" fill="#111"/>';
  if (has('spotlights')) s += '<circle cx="14" cy="58" r="6" fill="#ffe680" stroke="#222" stroke-width="2"/>';
  if (has('snorkel')) s += '<path d="M102 70 L108 38 L118 30" fill="none" stroke="#111" stroke-width="5" stroke-linecap="round"/>';
  if (has('roofrack')) s += '<rect x="124" y="33" width="68" height="4" fill="' + dark + '"/><path d="M130 37 v3 M186 37 v3" stroke="' + dark + '" stroke-width="3"/>';
  if (has('rooftent')) s += '<rect x="120" y="18" width="76" height="15" rx="3" fill="#5f6b3a" stroke="#3e4626"/>';
  if (has('awning')) s += '<rect x="124" y="37" width="66" height="4" rx="2" fill="#2f3a2a"/>';
  if (has('lightbar')) s += '<rect x="130" y="' + (has('roofrack') ? 29 : 35) + '" width="50" height="4" rx="2" fill="#fff7c2" stroke="#222"/>';
  s += '</g>' + wheel(72) + wheel(232) + '</svg>';
  return s;
}
function drawWallet() {
  $('wwho').textContent = (wal.name || 'YOUR').toUpperCase() + "'S WALLET";
  $('wcash').textContent = money(wal.cash);
  $('wpour').textContent = wal.pour ? 'This pour: +' + money(wal.pour) : 'Every job you do pays in here.';
  $('wbanked').textContent = 'Earned all up: ' + money(wal.banked);
  $('wpurse').innerHTML = wal.purse || '';
  document.querySelectorAll('#wallet .tabs button[data-tab]').forEach(b => b.classList.toggle('on', b.dataset.tab === wTab));
  const body = $('wbody');
  let note = '', can = false;
  if (wTab === 'garage') {
    if (!wal.ute) body.innerHTML = '<div class="garage"><div class="n hd">No ute yet</div><div class="kitl">Save up and pick one from the Utes tab. A Hilux is ' + money((shop.utes[0] || {price: 0}).price) + '.</div></div>';
    else {
      const u = shop.utes.find(x => x.id === wal.ute) || {name: wal.ute};
      const names = wal.kit.map(k => (shop.kit.find(x => x.id === k) || {name: k}).name);
      body.innerHTML = '<div class="garage">' + uteSvg(wal.ute, wal.kit) + '<div class="n hd">' + esc(u.name) + '</div><div class="kitl">' + (names.length ? esc(names.join(' · ')) : 'Stock standard. Kit it out from the 4x4 and Camping tabs.') + '</div></div>';
    }
    note = 'Your ute is yours to drive when the crew knocks off.';
  } else {
    const list = wTab === 'utes' ? shop.utes : shop.kit.filter(k => k.shop === wTab);
    body.innerHTML = '<div class="items">' + list.map(it => {
      const owned = wTab === 'utes' ? wal.utes.includes(it.id) : wal.kit.includes(it.id);
      const short = !owned && wal.cash < it.price;
      const cls = 'it' + (it.id === wPick ? ' pick' : '') + (owned ? ' have' : '') + (short ? ' short' : '');
      const pr = owned ? (wTab === 'utes' ? (wal.ute === it.id ? 'Driving it' : 'Yours: tap to drive') : 'Fitted') : money(it.price) + (short ? ' · ' + money(it.price - wal.cash) + ' short' : '');
      return '<button class="' + cls + '" data-id="' + it.id + '"><span class="n hd">' + esc(it.name) + '</span><span class="l">' + esc(it.line || 'Ute') + '</span><span class="pr hd">' + pr + '</span></button>';
    }).join('') + '</div>';
    const it = list.find(x => x.id === wPick);
    if (!it) note = wTab === 'utes' ? 'Pick a ute. You drive the one you picked last.' : (wal.ute ? 'Pick some kit for your ute.' : 'Buy a ute first, then kit it out.');
    else {
      const owned = wTab === 'utes' ? wal.utes.includes(it.id) : wal.kit.includes(it.id);
      const need = it.needs && !wal.kit.includes(it.needs) ? (shop.kit.find(x => x.id === it.needs) || {}).name : '';
      if (owned && wTab === 'utes') { note = 'Hold to drive the ' + it.name + '.'; can = wal.ute !== it.id; }
      else if (owned) note = 'Already on the ute.';
      else if (wTab !== 'utes' && !wal.ute) note = 'Buy a ute first.';
      else if (need) note = 'Needs the ' + need.toLowerCase() + ' first.';
      else if (wal.cash < it.price) note = money(it.price - wal.cash) + ' to go. Keep pouring.';
      else { note = it.name + ' for ' + money(it.price) + '. Leaves ' + money(wal.cash - it.price) + '.'; can = true; }
    }
  }
  $('wnote').textContent = note;
  $('wbuy').disabled = !can;
  $('wbuy').style.display = wTab === 'garage' ? 'none' : '';
  const drive = wTab === 'utes' && wal.utes.includes(wPick);
  $('wbuy').querySelector('span').textContent = drive ? 'HOLD TO DRIVE' : 'HOLD TO BUY';
}
$('wbody').addEventListener('pointerdown', (e) => { const b = e.target.closest('button.it'); if (!b) return; wPick = b.dataset.id; drawWallet(); buzz(BUZZ.press); });
holdButton($('wbuy'), 700, () => { if (wPick) send('buy ' + wPick); });
function onBought(j) { if (j.why) toast(j.why); else { buzz(BUZZ.done); stars($('wcash'), 20); wPick = ''; wTab = 'garage'; } setTimeout(drawWallet, 120); }
function showWalletBtn() { $('walletbtn').classList.toggle('on', screen === 'play' || screen === 'pause'); if (walletOpen && screen !== 'play' && screen !== 'pause') closeWallet(); if (screen === 'sign' && walletOpen) closeWallet(); }
connect();
</script>
</body>
</html>
"""
