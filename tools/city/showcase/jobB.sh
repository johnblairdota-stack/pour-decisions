cd /tmp/claude-0/cbdr
R="/tmp/claude-0/bl/bin/python /home/user/pour-decisions/tools/blender/spire/render_pairs.py /tmp/claude-0/mega/pairs.json p47 width=1000"
CYC_SAMPLES=32 timeout 2600 $R only=queenswharf_kurilpa_2025,queenswharf_abutment_2023,queenswharf_river_2025,william1_southbank_2025 > p47.log 2>&1; cp p47/cams.json p47/cams_a.json
CYC_SAMPLES=32 timeout 2600 $R only=skytower_kp_2019,skytower_kp_dec2018,skytower_kp_jan2019,skytower_kp_apr2019,skytower_kp_2024 > p47b.log 2>&1; cp p47/cams.json p47/cams_b.json
CYC_SAMPLES=32 timeout 2600 $R only=william1_top_gardens,william1_emporium_2019,william1_victoria_2019,william1_sunset_2017 > p47c.log 2>&1
CYC_SAMPLES=32 timeout 2600 $R only=william1_river_2016 > p47d.log 2>&1
ls p47
CYC_SAMPLES=32 timeout 3000 $R only=skytower_gardens_oct2019 > p47g.log 2>&1; ls p47 | wc -l
