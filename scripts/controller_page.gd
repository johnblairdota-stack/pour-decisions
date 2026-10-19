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
	return PAGE.replace("__WS_PORT__", str(ws_port))

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
html,body{margin:0;height:100%;background:var(--bg);color:var(--bone);font-family:Barlow,system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;font-weight:600;overflow:hidden}
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
.btn.gold .face{animation:goldbeat .3s ease-in-out infinite;box-shadow:0 1.4vmin 0 var(--lip),0 0 0 1.2vmin rgba(255,210,63,.35),0 0 8vmin rgba(255,210,63,.8)}
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
#helping{position:absolute;left:34vw;width:33vw;bottom:4vmin;z-index:14;background:#2a2410;border:2px solid var(--gold);color:var(--bone);border-radius:3vmin;padding:1.6vmin 2.4vmin;font-size:3.1vmin;display:none}
#helping.on{display:block}
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
#ljobs .job .n .sq svg{width:5vmin;height:4.2vmin}
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
#gate b{font-family:"Barlow Condensed",sans-serif;font-weight:800;font-size:10vmin;color:var(--gold)}
#gate .go{font-family:"Barlow Condensed",sans-serif;font-weight:800;background:var(--gold);color:#2a1d00;border-radius:3vmin;padding:2.4vmin 6vmin;box-shadow:0 1.2vmin 0 #b17a00}
#ios{display:none;max-width:80vmin;font-size:3.6vmin;color:#c9c6bd;line-height:1.4;border:1.5px solid rgba(255,255,255,.18);border-radius:3vmin;padding:2.4vmin 3vmin}
#status{position:fixed;right:3vmin;bottom:2vmin;font-size:2.6vmin;color:var(--dim);z-index:12}
@media (orientation:portrait){#rotate{display:flex}}
@media (prefers-reduced-motion:reduce){*{animation-duration:.01s!important;animation-iteration-count:1!important}}
</style>
</head>
<body>
<canvas id="fx"></canvas>
<div id="edge"></div>
<div id="toast" class="hd"></div>

<div id="play" class="screen">
  <button class="pausebtn" aria-label="Pause"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round"><path d="M9 5v14M15 5v14"/></svg></button>
  <div id="zone"><div class="lbl">Stick</div><div id="base"><div id="wedge"></div><div id="knob"></div></div></div>
  <div id="ticket">
    <button id="thead" aria-label="Your job, tap to swap">
      <svg class="hat" viewBox="0 0 24 20"><path d="M1 16h22v2H1z M3.5 16v-3a8.5 8.5 0 0 1 17 0v3z" fill="currentColor"/></svg>
      <span class="tt hd"><span class="k" id="tk">YOUR JOB</span><span class="n" id="tn">…</span></span>
      <span class="sw hd" id="tsw"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M7 4L3 8l4 4"/><path d="M3 8h14"/><path d="M17 20l4-4-4-4"/><path d="M21 16H7"/></svg>SWAP</span>
    </button>
    <div id="goal"></div>
    <div id="gauge"><svg viewBox="0 0 100 56"><path d="M8 50 A42 42 0 0 1 92 50" fill="none" stroke="#1a1d24" stroke-width="9"/><path id="g1" fill="none" stroke-width="9"/><path id="g2" fill="none" stroke-width="9"/><path id="g3" fill="none" stroke-width="9"/><line id="needle" x1="50" y1="50" x2="50" y2="12" stroke="#1b1a17" stroke-width="3.4" stroke-linecap="round"/><circle cx="50" cy="50" r="5" fill="#1b1a17"/></svg><div class="read hd" id="gread">STEADY</div></div>
    <div id="steps"></div>
    <div id="tfoot"></div>
  </div>
  <div id="helping">The leading hand's helping with this step. Press anything to take it back.</div>
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

<div id="joined"><div class="big" id="jbig">P?</div><div><div class="k hd" id="jk">You're on the crew</div><div class="t hd" id="jt">You are Player ?</div><div class="s">Look for your tag on the TV. Everyone scans the same code; the next phone gets the next number.</div><div id="pdots"></div></div></div>
<div id="ghost"><div></div></div>
<div id="rotate">Turn your phone sideways<br><small style="color:#9a978f">the controller works in landscape</small></div>
<div id="gate"><b>POUR DECISIONS</b><span class="go">TAP TO JOIN THE CREW</span><div id="ios"><b>Full screen on iPhone:</b> tap Share, then <b>Add to Home Screen</b>, and open Pour Decisions from your home screen.</div></div>
<button id="fs" aria-label="Full screen"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"><path d="M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5"/></svg></button>
<div id="status">connecting…</div>
<script>
const PORT = __WS_PORT__;
const $ = (id) => document.getElementById(id);
const HAT = '<svg viewBox="0 0 24 20"><path d="M1 16h22v2H1z M3.5 16v-3a8.5 8.5 0 0 1 17 0v3z" fill="currentColor"/></svg>';
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
    if (j.s === 'lobby') { if (!!j.locked !== locked) { locked = !!j.locked; showScreen(); if (locked) buzz(BUZZ.done); } setCount(j.count); }
  } else if (j.t === 'roster') { roster = j.r; drawLobby(); drawSwap(); }
  else if (j.t === 'card') { card = j; drawTicket(); drawLobby(); }
  else if (j.t === 'now') { now = j; drawSteps(); }
  else if (j.t === 'gauge') drawGauge(j);
  else if (j.t === 'nudge') setNudge(j.lvl);
  else if (j.t === 'toast') toast(j.msg);
}
function showScreen() {
  const lobby = screen === 'lobby';
  $('lobby').classList.toggle('on', lobby && !locked);
  $('locked').classList.toggle('on', lobby && locked);
  $('play').classList.toggle('on', !lobby);
  if (!lobby) closeSwap();
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
let lastStep = -1;
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
  el.innerHTML = html;
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
  s.split(',').forEach(x => { if (x) { const f = x.split(':'); want[f[0]] = {verb: (f[1] || '').replace(/_/g, ' '), p: parseFloat(f[2] || '-1'), urgent: f[3] === '1', gold: f[4] === '1', alarm: f[5] === '1'}; } });
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
    const g = !!(w && w.gold);
    if (g && !el.classList.contains('gold')) { stars(el, 14); buzz(BUZZ.gold); }
    el.classList.toggle('gold', g);
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
  if (swapOpen) return;
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
  return '<button class="job ' + cls + '" data-id="' + r.id + '" style="--c:#' + r.col + '"><span class="n"><span class="sq">' + HAT + '</span>' + esc(r.name) + extra + '</span><span class="w">' + esc(r.line) + '</span></button>';
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
  if (m) { $('ln').textContent = m.name; document.documentElement.style.setProperty('--job', '#' + m.col); }
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
    if (r.p === me.p) return '<div class="job mine" style="--c:#' + r.col + '"><span class="n">' + HAT + esc(r.name) + '</span><span class="w">you, P' + r.p + '</span></div>';
    if (r.p > 0) return '<div class="job taken" style="--c:#' + r.col + '"><span class="n">' + LOCK + esc(r.name) + '<span class="ptag" style="background:#' + r.pc + '">P' + r.p + '</span></span><span class="w">' + esc(r.who) + '</span></div>';
    return '<button class="job' + (r.id === swapPick ? ' pick' : '') + '" data-id="' + r.id + '" style="--c:#' + r.col + '"><span class="n">' + HAT + esc(r.name) + '</span><span class="w">bot ' + esc(r.who) + ' · ' + esc(r.line) + '</span></button>';
  }).join('');
  const free = roster.filter(r => !r.p).length;
  $('swapgo').disabled = !swapPick;
  $('swapnote').textContent = free ? 'Tap a job a bot’s doing, then hold to swap. Your chibi stands still while this is open.' : 'Every job has a player on it right now.';
}
$('jobs').addEventListener('pointerdown', (e) => { const b = e.target.closest('button.job'); if (!b) return; swapPick = b.dataset.id; drawSwap(); buzz(BUZZ.press); });
holdButton($('swapgo'), 700, () => { if (swapPick) send('swap ' + swapPick); closeSwap(); });
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
$('gate').addEventListener('pointerdown', () => { $('gate').style.display = 'none'; goFull(); setTimeout(fsShow, 400); });
if (location.search.includes('nogate')) $('gate').style.display = 'none';
connect();
</script>
</body>
</html>
"""
