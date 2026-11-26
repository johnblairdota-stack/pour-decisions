cd /tmp/claude-0/cbdr
R="/tmp/claude-0/bl/bin/python /home/user/pour-decisions/tools/blender/spire/render_pairs.py /tmp/claude-0/mega/pairs_old.json o3 width=1000"
CYC_SAMPLES=32 timeout 2600 $R only=sa_aerial_ne_dusk,sa_ann_queen_corner,sa_ann_st_far,sa_cathedral_forecourt,sa_crane_from_nw > o3_0.log 2>&1
CYC_SAMPLES=32 timeout 2600 $R only=sa_crane_from_south,sa_fly_by_east,sa_orient_front,sa_queen_st_willahra > o3_1.log 2>&1
CYC_SAMPLES=32 timeout 2600 $R only=hs_p01_drone_se,hs_p04_drone_dusk_se,hs_p06_drone_south,hs_p07_drone_sw_citycat > o3_2.log 2>&1
CYC_SAMPLES=32 timeout 2600 $R only=hs_p09_pier_face_on,hs_p10_drone_lawns_se,hs_p12_river_felons,hs_p13_kp_bank_ferry > o3_3.log 2>&1
CYC_SAMPLES=32 timeout 2600 $R only=sah_ann_st_streetscape,sah_customs_house_river,sah_roof > o3_5.log 2>&1
CYC_SAMPLES=32 timeout 2600 $R only=hsh_main_lawn,hsh_riverwalk_under_bridge,hsh_wilson_outlook,hsh_citycat > o3_6.log 2>&1
CYC_SAMPLES=48 timeout 3000 /tmp/claude-0/bl53/bin/python /tmp/claude-0/mega/tools/open_strips.py open8 > open8.log 2>&1
echo ALLDONE
