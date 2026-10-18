# Mapillary street-level images — not downloaded yet

Status (2026-10-18): **skipped. A token is needed.**

Mapillary images are CC BY-SA 4.0. But every Mapillary API call needs an access token. This includes the image search (`graph.mapillary.com`) and the coverage tiles (`tiles.mapillary.com`). Without a token, both return HTTP 403 or "Invalid OAuth 2.0 Access Token". I tested both.

## What John must do (about 5 minutes, free)

1. Go to https://www.mapillary.com/signup and make a free account. (You can also log in with a Facebook account.)
2. Go to https://www.mapillary.com/dashboard/developers.
3. Click **Register application**. Name: `pour-decisions-reference`. Website: the GitHub repo URL. Callback URL: `https://localhost/`. Tick **Read** access only.
4. After you save, copy the **Client Token**. It starts with `MLY|`.
5. Give the token to Claude in chat. Do not commit the token to git.

## What Claude will do with the token

- Search images in a box about 400 m around the Riverlight centre (-27.4436709, 153.0855133):
  `https://graph.mapillary.com/images?access_token=TOKEN&bbox=153.0810,-27.4473,153.0900,-27.4400&fields=id,captured_at,compass_angle,computed_geometry,thumb_2048_url,creator&limit=2000`
- Keep images on MacArthur Ave, Angora Rd, Parkside Circuit, the RiverWalk and park, and the CityCat terminal.
- Save `index.geojson` (id, location, date, heading, creator) and the 2048 px thumbnails, resized to 1600 px.
- Write a CREDITS.md. The licence is CC BY-SA 4.0, credit "© Mapillary contributors" plus each creator name.
