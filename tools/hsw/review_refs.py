"""Apply a hand review of the contact sheets: move rejected photos to refs/hsw/_rejected (not deleted) and
re-file mis-sorted ones, keeping download_state.json in step. Then run fetch_refs.py manifest sheets.
    <blender python> -I tools/hsw/review_refs.py <sites_dir>"""
import json
import os
import shutil
import sys

OUT = os.path.join(sys.argv[1], "refs", "hsw")
REJECT = """cm_188c0c30 cm_94e5acff gg_26d78945 gg_32883724 gg_538687c4 gg_832cfc6d gg_aae36da1 gg_c0b9fe29
gg_5170de01 gg_33363613 gg_a8282e33 pg_16a850a8 pg_34b1a768 pg_4597ddd2 pg_59fcf8d2 pg_5a563a94 pg_5da97590
pg_71bc3796 pg_78539883 pg_883027f4 pg_8bab695b pg_a66aa5cd pg_ac5ea300 pg_c99dcde0 pg_ead9da19 pg_f1d35091
pg_fc2e49ef cm_4088bcda cm_f163172a fl_05223993 fl_4ae71bb3 fl_82cf218d fl_8d746cc9 fl_a2f4a04e fl_a5fef64f
fl_d0395125 pg_03ddf4df pg_2b0cf507 pg_316f177b pg_4042547c pg_578f5778 pg_8c233bf1 pg_8e5af01f pg_9883c612
pg_a88285ac pg_c75561ff pg_f79f9907 pg_f9a8d595 cm_0278fd80 cm_0817120d cm_6a666de6 cm_77ffcf26 cm_7a782622
cm_d424415f cm_f0ee7b5f gg_1d29b57d gg_2377c854 gg_25120e0d gg_273b9bd3 gg_2804ec81 gg_353d43d3 gg_4bde08c5
gg_586d317b gg_610fd01a gg_687f2c1f gg_8ba2b4f4 gg_82c8c199 gg_b5abe0b1 gg_e30afb68 gg_ec437529 gg_edaab5bd
gg_f199f87e gg_f5c5bfeb gg_fe66a820 pg_101fdefa pg_361d0bad pg_689a5896 pg_882553e6 pg_994d8efb pg_cbca131d
pg_f9318153 cm_0c8331b3 cm_1e6aadfe cm_26a8928d cm_3a62e35a cm_62abb1a5 cm_8a9d4e29 cm_a71ae928 cm_c6b5e8da
cm_d386dab2 gg_15a9fe52 gg_1998ce0e gg_24d4adfa gg_2b650011 gg_8136e37c gg_8a882758 gg_8f327c07 gg_be1a1468
gg_e72d9833 gg_f869f815 gg_2a1c430b gg_9b777aab gg_c541300b gg_1a2ab58e gg_d7bbf868 fl_185c02d3 fl_8facbf6d
fl_951b9796 pg_3b14ac09 pg_481dda7b pg_c270f479 pg_eecca372 pg_f430fde2 cm_037526f7 cm_18c1f295 cm_368cd91d
cm_b4bf9ee7 cm_bff55fbf cm_dfb0205e cm_f0a68b1a cm_da7b82b0 cm_403d4c0b gg_ef29463b pg_71bcb8c9 cm_2fbdb6cf
cm_455e8a2c cm_793e472c gg_20c5442e gg_2c73005b gg_722be29a gg_03340ac4 gg_e22763ec gg_96240c97""".split()
REFILE = {   # Story Bridge Hotel (Kangaroo Pt pub) street views -> bridge approach; corten panel -> lift tower
    **{k: "bridge_deck_and_approach" for k in "cm_06b8daee cm_117341ea cm_2c1a240d cm_382d842f cm_492cdec9 "
       "cm_4b54c167 cm_57eb05a7 cm_85ab5e9a cm_97c6c5cf cm_a878f88e cm_e2060ba4 cm_fef9bb0f".split()},
    "cm_7e15da13": "bridge_piers", "cm_6fee4ccf": "lift_tower_stairs", "cm_c8576e02": "cliffs",
    "cm_2bed680f": "overview_aerial", "cm_beea84ca": "overview_aerial",
}
sp = os.path.join(OUT, "download_state.json")
st = json.load(open(sp))
rej = os.path.join(OUT, "_rejected")
os.makedirs(rej, exist_ok=True)
moved = refiled = 0
for d in os.listdir(OUT):
    dd = os.path.join(OUT, d)
    if not os.path.isdir(dd) or d in ("sheets", "_rejected"):
        continue
    for f in os.listdir(dd):
        key = f[:-4]
        if key in REJECT:
            shutil.move(os.path.join(dd, f), os.path.join(rej, f))
            if f in st:
                st[f]["ok"] = False
                st[f]["why"] = "rejected in review (interior/food/people/drawing/proposal render/elsewhere)"
            moved += 1
        elif key in REFILE and REFILE[key] != d:
            nd = os.path.join(OUT, REFILE[key])
            os.makedirs(nd, exist_ok=True)
            shutil.move(os.path.join(dd, f), os.path.join(nd, f))
            if f in st:
                st[f]["category"] = REFILE[key]
            refiled += 1
json.dump(st, open(sp, "w"))
print("rejected", moved, "refiled", refiled)
