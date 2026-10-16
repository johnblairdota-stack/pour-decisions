## A small QR code encoder (byte mode, error correction level L, versions 1-5)
## so the join address can be scanned straight off the TV with a phone camera.
## Follows the QR spec layout; mask pattern 0.
extends RefCounted

# Data codewords and EC codewords per block for level L, versions 1..5 (one block each)
const DATA_L := [0, 19, 34, 55, 80, 108]
const EC_L := [0, 7, 10, 15, 20, 26]

## Returns rows of booleans (true = dark), or [] if the text is too long.
static func encode(text: String) -> Array:
	var bytes := text.to_utf8_buffer()
	var ver := 0
	for v in range(1, 6):
		if 4 + 8 + bytes.size() * 8 <= DATA_L[v] * 8:
			ver = v
			break
	if ver == 0:
		return []
	# Bit stream: mode 0100 (byte), 8-bit length, data, terminator, padding
	var bits: Array[int] = []
	_push(bits, 0b0100, 4)
	_push(bits, bytes.size(), 8)
	for b in bytes:
		_push(bits, b, 8)
	var cap: int = DATA_L[ver] * 8
	for i in mini(4, cap - bits.size()):
		bits.append(0)
	while bits.size() % 8 != 0:
		bits.append(0)
	var data: Array[int] = []
	for i in range(0, bits.size(), 8):
		var v := 0
		for j in 8:
			v = (v << 1) | bits[i + j]
		data.append(v)
	var pad := [0xEC, 0x11]
	var k := 0
	while data.size() < DATA_L[ver]:
		data.append(pad[k % 2])
		k += 1
	var ecc := _rs_remainder(data, _rs_divisor(EC_L[ver]))
	var codewords: Array[int] = data.duplicate()
	codewords.append_array(ecc)

	var size := 17 + 4 * ver
	var mods := []
	var fn := []
	for y in size:
		var row := []
		var frow := []
		row.resize(size)
		frow.resize(size)
		row.fill(false)
		frow.fill(false)
		mods.append(row)
		fn.append(frow)
	# Timing patterns
	for i in size:
		_mark(mods, fn, 6, i, i % 2 == 0)
		_mark(mods, fn, i, 6, i % 2 == 0)
	# Finder patterns with separators
	for c in [[3, 3], [size - 4, 3], [3, size - 4]]:
		for dy in range(-4, 5):
			for dx in range(-4, 5):
				var x: int = c[0] + dx
				var y: int = c[1] + dy
				if x < 0 or y < 0 or x >= size or y >= size:
					continue
				var d := maxi(absi(dx), absi(dy))
				_mark(mods, fn, x, y, d != 2 and d != 4)
	# Alignment pattern (versions 2+): one, near the bottom right
	if ver >= 2:
		var a := size - 7
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				_mark(mods, fn, a + dx, a + dy, maxi(absi(dx), absi(dy)) != 1)
	# Reserve the format areas (filled in below) and the dark module
	_draw_format(mods, fn, size, 0)
	# Data, in the zigzag order
	var i_bit := 0
	var total := codewords.size() * 8
	var right := size - 1
	while right >= 1:
		if right == 6:
			right = 5
		for vert in size:
			for j in 2:
				var x := right - j
				var upward := ((right + 1) & 2) == 0
				var y := size - 1 - vert if upward else vert
				if not fn[y][x] and i_bit < total:
					mods[y][x] = ((codewords[i_bit >> 3] >> (7 - (i_bit & 7))) & 1) == 1
					i_bit += 1
		right -= 2
	# Mask 0: flip data modules where (x + y) is even
	for y in size:
		for x in size:
			if not fn[y][x] and (x + y) % 2 == 0:
				mods[y][x] = not mods[y][x]
	_draw_format(mods, fn, size, 0)
	return mods

static func _push(bits: Array[int], v: int, n: int) -> void:
	for i in range(n - 1, -1, -1):
		bits.append((v >> i) & 1)

static func _mark(mods: Array, fn: Array, x: int, y: int, dark: bool) -> void:
	mods[y][x] = dark
	fn[y][x] = true

## Format info: EC level L (01) and the mask number, BCH-protected.
static func _draw_format(mods: Array, fn: Array, size: int, mask: int) -> void:
	var data := (1 << 3) | mask
	var rem := data
	for i in 10:
		rem = (rem << 1) ^ ((rem >> 9) * 0x537)
	var bits := ((data << 10) | rem) ^ 0x5412
	for i in 6:
		_mark(mods, fn, 8, i, ((bits >> i) & 1) == 1)
	_mark(mods, fn, 8, 7, ((bits >> 6) & 1) == 1)
	_mark(mods, fn, 8, 8, ((bits >> 7) & 1) == 1)
	_mark(mods, fn, 7, 8, ((bits >> 8) & 1) == 1)
	for i in range(9, 15):
		_mark(mods, fn, 14 - i, 8, ((bits >> i) & 1) == 1)
	for i in 8:
		_mark(mods, fn, size - 1 - i, 8, ((bits >> i) & 1) == 1)
	for i in range(8, 15):
		_mark(mods, fn, 8, size - 15 + i, ((bits >> i) & 1) == 1)
	_mark(mods, fn, 8, size - 8, true)

static func _gf_mul(x: int, y: int) -> int:
	var z := 0
	for i in range(7, -1, -1):
		z = ((z << 1) ^ ((z >> 7) * 0x11D)) & 0xFF
		z ^= ((y >> i) & 1) * x
	return z & 0xFF

static func _rs_divisor(degree: int) -> Array[int]:
	var result: Array[int] = []
	result.resize(degree)
	result.fill(0)
	result[degree - 1] = 1
	var root := 1
	for i in degree:
		for j in degree:
			result[j] = _gf_mul(result[j], root)
			if j + 1 < degree:
				result[j] ^= result[j + 1]
		root = _gf_mul(root, 0x02)
	return result

static func _rs_remainder(data: Array[int], divisor: Array[int]) -> Array[int]:
	var result: Array[int] = []
	result.resize(divisor.size())
	result.fill(0)
	for b in data:
		var factor: int = b ^ result[0]
		result.remove_at(0)
		result.append(0)
		for i in result.size():
			result[i] ^= _gf_mul(divisor[i], factor)
	return result

## A crisp texture of the code with a quiet zone, `px` pixels per module.
static func texture(text: String, px := 6) -> ImageTexture:
	var m := encode(text)
	if m.is_empty():
		return null
	var n: int = m.size()
	var q := 4
	var w := (n + q * 2) * px
	var img := Image.create(w, w, false, Image.FORMAT_RGB8)
	img.fill(Color.WHITE)
	for y in n:
		for x in n:
			if m[y][x]:
				img.fill_rect(Rect2i((x + q) * px, (y + q) * px, px, px), Color.BLACK)
	return ImageTexture.create_from_image(img)
