"""Solid heightfield meshes from a top-surface grid + ground grid + mask (numpy, fast).
Used for the LiDAR roofscape (buildings), the cathedral (0.5 m) and Howard Smith Wharves."""
import numpy as np

import common as C


def voxel_mesh(name, col, idx, origin, size, key):
    """Outer faces of a set of voxels. idx (N, 3) int grid indices; origin = local (x, y, z) of index 0."""
    idx = np.asarray(idx, "i8")
    lo = idx.min(0)
    sh = idx.max(0) - lo + 3
    occ = np.zeros(sh, bool)
    p = idx - lo + 1
    occ[p[:, 0], p[:, 1], p[:, 2]] = True
    corner = np.array([[0, 0, 0], [1, 0, 0], [1, 1, 0], [0, 1, 0], [0, 0, 1], [1, 0, 1], [1, 1, 1], [0, 1, 1]])
    # face corner lists (outward winding) per direction
    FACES = {(1, 0, 0): [1, 2, 6, 5], (-1, 0, 0): [0, 4, 7, 3], (0, 1, 0): [3, 7, 6, 2],
             (0, -1, 0): [0, 1, 5, 4], (0, 0, 1): [4, 5, 6, 7], (0, 0, -1): [0, 3, 2, 1]}
    quads = []
    for d, cs in FACES.items():
        nb = np.roll(occ, shift=(-d[0], -d[1], -d[2]), axis=(0, 1, 2))
        sel = occ & ~nb
        v = np.argwhere(sel)
        q = v[:, None, :] + corner[cs][None, :, :]
        quads.append(q.reshape(-1, 3))
    pts = np.concatenate(quads)
    uniq, inv = np.unique(pts, axis=0, return_inverse=True)
    verts = (uniq + lo - 1) * size + np.asarray(origin)
    faces = inv.reshape(-1, 4)
    ob = C.mesh_fast(name, verts, faces, col, key)
    return ob, int(len(idx)), int(len(faces))


def heightfield(name, col, top, ground, mask, x0, y1, step, key):
    """Roof quads on every masked cell (corner z = mean of the masked cells round it) and walls down to
    the ground on every edge between a masked and an unmasked cell. Grid rows run north -> south."""
    H, W = mask.shape
    m = np.pad(mask, 1)
    t = np.pad(np.where(mask, top, 0.0), 1)
    g = np.pad(ground, 1, mode="edge")
    # corner (i, j) touches padded cells (i, j), (i, j+1), (i+1, j), (i+1, j+1)
    cells_m = [m[:-1, :-1], m[:-1, 1:], m[1:, :-1], m[1:, 1:]]
    cells_t = [t[:-1, :-1], t[:-1, 1:], t[1:, :-1], t[1:, 1:]]
    cells_g = [g[:-1, :-1], g[:-1, 1:], g[1:, :-1], g[1:, 1:]]
    cnt = sum(c.astype("f4") for c in cells_m)
    ztop = sum(tt * mm for tt, mm in zip(cells_t, cells_m)) / np.maximum(cnt, 1)
    zbot = np.minimum.reduce(cells_g) - 0.3
    used = cnt > 0
    ci = np.full(used.shape, -1, "i8")
    n = int(used.sum())
    ci[used] = np.arange(n)
    rr, cc = np.nonzero(used)
    X = x0 + cc * step
    Y = y1 - rr * step
    vt = np.stack([X, Y, ztop[used]], -1)
    vb = np.stack([X, Y, zbot[used]], -1)
    verts = np.concatenate([vt, vb])
    # roofs: cell (r, c) has corners (r, c), (r, c+1), (r+1, c+1), (r+1, c); CCW seen from above
    r, c = np.nonzero(mask)
    roofs = np.stack([ci[r + 1, c], ci[r + 1, c + 1], ci[r, c + 1], ci[r, c]], -1)
    walls = []
    # neighbour tests on the unpadded mask
    def edge(sel, a, b):
        ia, ib = ci[a], ci[b]
        return np.stack([ia, ib, ib + n, ia + n], -1)[sel]
    north = np.ones_like(mask)
    north[1:] = ~mask[:-1]
    south = np.ones_like(mask)
    south[:-1] = ~mask[1:]
    west = np.ones_like(mask)
    west[:, 1:] = ~mask[:, :-1]
    east = np.ones_like(mask)
    east[:, :-1] = ~mask[:, 1:]
    walls.append(edge(north[r, c], (r, c + 1), (r, c)))            # top edge, faces north
    walls.append(edge(south[r, c], (r + 1, c), (r + 1, c + 1)))    # bottom edge, faces south
    walls.append(edge(west[r, c], (r, c), (r + 1, c)))             # left edge, faces west
    walls.append(edge(east[r, c], (r + 1, c + 1), (r, c + 1)))     # right edge, faces east
    faces = np.concatenate([roofs] + walls)
    ob = C.mesh_fast(name, verts, faces, col, key)
    return ob, int(len(roofs)), int(sum(len(w) for w in walls))
