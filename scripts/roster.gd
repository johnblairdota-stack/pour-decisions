## The named crew. Each person picks who they play; the bots are whoever's
## left. Looks are cosmetic: the hard hat stays the colour of the job.
extends RefCounted

const CHARACTERS := [
	{"id": "macca", "name": "Macca", "skin": "f1c7a3", "hair": "6b4a2b", "look": "moustache", "line": "Leading hand. Seen every way a pour can go wrong, twice."},
	{"id": "tash", "name": "Tash", "skin": "d9a37a", "hair": "2b1a12", "look": "ponytail", "line": "Knows every truck driver by first name."},
	{"id": "gus", "name": "Gus", "skin": "8d5a3b", "hair": "1b1410", "look": "beard", "line": "Big, quiet, never drops a clamp."},
	{"id": "priya", "name": "Priya", "skin": "b07850", "hair": "1a1210", "look": "bun", "line": "Ex-site engineer. Reads the docket twice."},
	{"id": "robbo", "name": "Robbo", "skin": "f3cfb1", "hair": "c98a3a", "look": "earmuffs", "line": "Second-year apprentice. Fast, keen and loud."},
	{"id": "jules", "name": "Jules", "skin": "c69472", "hair": "3a2414", "look": "sunnies", "line": "Whistle like a kettle. Dogs a load in one go."},
	{"id": "nev", "name": "Nev", "skin": "eab99a", "hair": "c9c9c9", "look": "beard", "line": "Forty years on the tools. Still first on site."},
	{"id": "kiri", "name": "Kiri", "skin": "6e4630", "hair": "120d0a", "look": "sunnies", "line": "Rigger. Doesn't love heights. Does them anyway."},
]
## Who the bots are by default, job by job.
const DEFAULT_CHAR := {"boom": "jules", "line": "kiri", "pump": "tash", "poker": "gus", "screed": "robbo", "hose": "nev"}


static func char_info(id: String) -> Dictionary:
	for c in CHARACTERS:
		if c["id"] == id:
			return c
	return CHARACTERS[0]
