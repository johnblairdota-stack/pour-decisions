"""Leaf-card foliage (step 7f). Small textured quads ("cards") scattered in crown volumes, shrub clumps,
tufts and hanging strands. The leaf texture is procedural (preview.setup_morning: material prop
shader="leaf"), no photo textures. numpy throughout so thousands of cards stay fast."""
import math

import numpy as np

import common as C


class Foliage:
    def __init__(self, seed=1):
        self.v, self.f, self.uv = [], [], []
        self.n = 0
        self.rng = np.random.default_rng(seed)

    def _cards(self, P, N, S, up_bias=0.0, tall=1.0):
        """Cards at points P (k,3) with normals N (k,3) and sizes S (k,)."""
        k = len(P)
        if k == 0:
            return
        N = N / np.linalg.norm(N, axis=1, keepdims=True)
        ref = np.where(np.abs(N[:, 2:3]) > 0.9, np.array([[1.0, 0, 0]]), np.array([[0, 0, 1.0]]))
        A = np.cross(N, ref)
        A /= np.linalg.norm(A, axis=1, keepdims=True)
        B = np.cross(N, A)
        if up_bias:
            B = B * (1 - up_bias) + np.array([0, 0, 1.0]) * up_bias
            B /= np.linalg.norm(B, axis=1, keepdims=True)
        h = (S / 2)[:, None]
        corners = [P - A * h - B * h * tall, P + A * h - B * h * tall, P + A * h + B * h * tall, P - A * h + B * h * tall]
        V = np.stack(corners, 1).reshape(-1, 3)
        F = (np.arange(k)[:, None] * 4 + np.arange(4)[None, :]) + self.n
        self.v.append(V)
        self.f.append(F)
        self.uv.append(np.tile(np.array([[0, 0], [1, 0], [1, 1], [0, 1]], "f4"), (k, 1)))
        self.n += 4 * k

    def cloud(self, c, radii, count, size, shell=0.7, top_bias=0.0):
        """Cards filling an ellipsoid: mostly near the surface (shell), normals pointing outwards."""
        r = self.rng
        d = r.normal(size=(count, 3))
        d /= np.linalg.norm(d, axis=1, keepdims=True)
        if top_bias:
            d[:, 2] = np.abs(d[:, 2]) * top_bias + d[:, 2] * (1 - top_bias)
            d /= np.linalg.norm(d, axis=1, keepdims=True)
        rad = shell + (1 - shell) * r.random(count) ** 0.5
        P = np.asarray(c) + d * np.asarray(radii) * rad[:, None]
        N = d + r.normal(scale=0.6, size=(count, 3))
        S = size * (0.7 + 0.6 * r.random(count))
        self._cards(P, N, S)

    def tufts(self, c, radius, count, height):
        """Strappy clumps (lomandra, grasses): tall narrow cards, near vertical."""
        r = self.rng
        a = r.random(count) * 2 * math.pi
        rr = radius * r.random(count) ** 0.5
        P = np.stack([c[0] + np.cos(a) * rr, c[1] + np.sin(a) * rr, np.full(count, c[2] + height * 0.45)], 1)
        N = np.stack([np.cos(a), np.sin(a), np.zeros(count)], 1)
        self._cards(P, N, height * (0.7 + 0.5 * r.random(count)), up_bias=0.8, tall=1.0)

    def strands(self, top_pts, normal, length, step=0.45, size=0.55):
        """Trailing plants: a line of cards hanging down from each point, pushed out along `normal`."""
        r = self.rng
        P, N, S = [], [], []
        for x, y, z in top_pts:
            ln = length * (0.4 + 0.6 * r.random())
            k = max(2, int(ln / step))
            for j in range(k):
                out = 0.15 + 0.08 * math.sin(j)
                P.append((x + normal[0] * out + r.normal(scale=0.08), y + normal[1] * out + r.normal(scale=0.08), z - j * step))
                N.append((normal[0] + r.normal(scale=0.5), normal[1] + r.normal(scale=0.5), r.normal(scale=0.3)))
                S.append(size * (1.0 - 0.4 * j / k))
        if P:
            self._cards(np.array(P), np.array(N), np.array(S))

    def object(self, name, col, rgb, rgb2, translucency=0.35):
        if not self.v:
            return None
        V = np.concatenate(self.v)
        F = np.concatenate(self.f)
        UV = np.concatenate(self.uv)
        ob = C.mesh_fast(name, V, F, col, "tree")
        lay = ob.data.uv_layers.new(name="facade")
        lay.data.foreach_set("uv", UV.ravel())
        m = C.material_rgb(name + "_leaf", rgb)
        m["shader"] = "leaf"
        m["leaf2"] = list(rgb2)
        m["translucency"] = translucency
        ob.data.materials[0] = m
        return ob
