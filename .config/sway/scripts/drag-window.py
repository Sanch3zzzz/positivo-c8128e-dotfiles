#!/usr/bin/env python3
"""Arrastar janelas com o mouse: MOD + arrastar (botao esquerdo).

NAO usa floating_modifier (o drag nativo do sway engole o --release e o
script nunca veria o soltar do botao). O script controla tudo:

  start (bindsym --whole-window $mod+Button1):
    - pega a janela FOCADA (clicar com MOD foca a janela sob o cursor).
    - se tiled  -> floating enable e o 'follow' depois re-tila + swap.
    - se ja flutuante -> deixa como esta e o 'follow' so move.
    - spawna o 'follow' como root (sudo -n, pra ler /dev/input).

  follow <nid> <mode>:
    - le os deltas do ponteiro (touchpad ABS normalizado p/ 1366x768;
      mouse REL) e move a janela por deslocamento relativo.
    - finaliza sozinho quando: (a) o arquivo STOP aparece (bind --release)
      ou (b) BTN_LEFT solta (cobre clique fisico com o MOD soltado antes).
    - no finalize (mode=tiled): pega o rect do fantasma ANTES de re-tilar
      (centro = onde o cursor estava) -> alvo de drop = janela cujo rect
      contem esse centro -> floating disable + swap.

  end (bindsym --whole-window --release $mod+Button1):
    - cria o STOP e espera o follow sair.
"""
import glob
import json
import os
import select
import subprocess
import sys
import time

FLAG = "/tmp/sway-drag-window.state"
STOP = "/tmp/sway-drag-window.stop"
LOG = "/tmp/sway-drag-window.log"
SCRIPT = os.path.abspath(__file__)
MOVE_STEP = 16          # px por comando "move" durante o follow
STEP_MIN = 0.03         # throttle entre lotes de move
BTN_LEFT = 0x110        # ecodes.BTN_LEFT
SWAP_MIN = 30           # deslocamento minimo (px) pra considerar que houve drag
WIN_TYPES = ("con", "floating_con")   # janelas no get_tree


def sock():
    for s in sorted(glob.glob("/run/user/*/sway-ipc.*.sock")):
        return s
    return None


def _env():
    env = dict(os.environ)
    env["SWAYSOCK"] = sock()
    return env


def tree_root():
    env = _env()
    try:
        d = json.loads(subprocess.check_output(["swaymsg", "-t", "get_tree"], env=env, timeout=2))
        return d[0] if isinstance(d, list) and d else d
    except Exception:
        return None


def cmd(*args):
    try:
        subprocess.run(["swaymsg"] + [str(a) for a in args], env=_env(), timeout=2,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass


def focus_leaf(root):
    """janela (folha) focada + se ela ja e flutuante."""
    node = [None]

    def walk(n):
        if n.get("focused"):
            node[0] = n
            return True
        for c in n.get("nodes", ()) + n.get("floating_nodes", ()):
            if walk(c):
                return True
        return False

    walk(root)
    return node[0], is_floating(node[0].get("id"), root) if node[0] else False


def is_floating(nid, root):
    out = [False]

    def walk(n, in_float):
        if n.get("type") in WIN_TYPES and n.get("id") == nid:
            out[0] = in_float
            return
        for c in n.get("nodes", ()):
            walk(c, in_float)
        for c in n.get("floating_nodes", ()):
            walk(c, True)

    walk(root, False)
    return out[0]


def rect_of(nid, root):
    def walk(n):
        if n.get("id") == nid and n.get("type") in WIN_TYPES:
            return n
        for c in n.get("nodes", ()) + n.get("floating_nodes", ()):
            r = walk(c)
            if r:
                return r
        return None
    node = walk(root)
    return (node.get("rect") or {}) if node else {}


def leaf_containing(x, y, root, exclude=None):
    """menor janela cuja rect contem o ponto (exceto exclude). retorna (node, ws)."""
    best = [None, None, float("inf")]

    def walk(n, ws):
        if n.get("type") == "workspace":
            ws = n
        if n.get("type") in ("con", "floating_con") and not n.get("nodes") and not n.get("floating_nodes"):
            if exclude is None or n.get("id") != exclude:
                r = n.get("rect") or {}
                if r and r["x"] <= x < r["x"] + r["width"] and r["y"] <= y < r["y"] + r["height"]:
                    area = r["width"] * r["height"]
                    if area < best[2]:
                        best[:] = [n, ws, area]
        for c in n.get("nodes", ()) + n.get("floating_nodes", ()):
            walk(c, ws)

    walk(root, None)
    return best[0], best[1]


def _node_ws(nid, root):
    res = [None]

    def walk(n, ws):
        if n.get("type") == "workspace":
            ws = n
        if n.get("id") == nid and n.get("type") in WIN_TYPES:
            res[0] = ws
        for c in n.get("nodes", ()) + n.get("floating_nodes", ()):
            walk(c, ws)

    walk(root, None)
    return res[0]


def streams():
    """fluxos de movimento do ponteiro:
       REL (mouse) -> deltas diretos;
       ABS (touchpad) -> posicao normalizada p/ 1366x768.
       ydotool virtual e touchscreen (FTSC) sao excluidos.
    """
    try:
        from evdev import InputDevice, ecodes, list_devices
    except Exception:
        return []
    out = []
    for path in list_devices():
        dev = None
        try:
            dev = InputDevice(path)
            caps = dev.capabilities()
            rel = caps.get(ecodes.EV_REL, ())
            abs_caps = caps.get(ecodes.EV_ABS, ())
            is_rel = ecodes.REL_X in rel and ecodes.REL_Y in rel and "ydotoold" not in dev.name
            is_abs = False
            if "Touchpad" in dev.name:
                codes = {c for c, _ in abs_caps}
                if ecodes.ABS_X in codes and ecodes.ABS_Y in codes:
                    is_abs = True
            if is_rel:
                out.append({"kind": "rel", "dev": dev})
            elif is_abs:
                xi = dict(abs_caps)[ecodes.ABS_X]
                yi = dict(abs_caps)[ecodes.ABS_Y]
                out.append({"kind": "abs", "dev": dev,
                            "sx": 1366 / max(1, xi.max - xi.min),
                            "sy": 768 / max(1, yi.max - yi.min),
                            "prev": None})
            else:
                dev.close()
        except Exception:
            if dev:
                try:
                    dev.close()
                except Exception:
                    pass
    return out


def follow(nid, mode):
    try:
        _follow(nid, mode)
    except Exception:
        import traceback
        try:
            with open(LOG, "a") as f:
                f.write(time.strftime("%H:%M:%S ") + traceback.format_exc())
        except Exception:
            pass
        os._exit(1)


def _follow(nid, mode):
    st = streams()
    if not st:
        _finalize(nid, mode)
        sys.exit(0)
    pdx = pdy = 0
    pending = []
    last_cmd = 0.0
    stopped = False
    why = None
    while not stopped:
        if os.path.exists(STOP):
            stopped = True
            why = "STOP"
            break
        r, _, _ = select.select([s["dev"] for s in st], [], [], 0.05)
        for dev in r:
            s = next(x for x in st if x["dev"] is dev)
            try:
                evs = dev.read()
            except (BlockingIOError, OSError):
                continue
            for ev in evs:
                if ev.type == 2:                      # EV_REL
                    if ev.code == 0:
                        pdx += ev.value
                    elif ev.code == 1:
                        pdy += ev.value
                elif ev.type == 3:                    # EV_ABS
                    if ev.code == 0:
                        s["x"] = ev.value
                    elif ev.code == 1:
                        s["y"] = ev.value
                elif ev.type == 0:                    # EV_SYN
                    if s.get("kind") == "abs" and "x" in s and "y" in s:
                        cur = (s["x"] * s["sx"], s["y"] * s["sy"])
                        if s.get("prev") is not None:
                            pdx += cur[0] - s["prev"][0]
                            pdy += cur[1] - s["prev"][1]
                        s["prev"] = cur
                elif ev.type == 1 and ev.code == BTN_LEFT and ev.value == 0:
                    # clique fisico solto: encerra mesmo sem o bind --release
                    stopped = True
                    why = "BTN_LEFT"
        if stopped:
            break
        if pdx or pdy:
            pending.append((pdx, pdy))
            pdx = pdy = 0
        now = time.monotonic()
        if pending and (now - last_cmd) >= STEP_MIN:
            moves = []
            for dx, dy in pending:
                while dy <= -MOVE_STEP:
                    moves.append("move up %dpx" % MOVE_STEP); dy += MOVE_STEP
                while dy >= MOVE_STEP:
                    moves.append("move down %dpx" % MOVE_STEP); dy -= MOVE_STEP
                while dx <= -MOVE_STEP:
                    moves.append("move left %dpx" % MOVE_STEP); dx += MOVE_STEP
                while dx >= MOVE_STEP:
                    moves.append("move right %dpx" % MOVE_STEP); dx -= MOVE_STEP
            pending = []
            if moves:
                cmd("[con_id=%d] %s" % (nid, "; ".join(moves)))
                last_cmd = now
    try:
        with open(LOG, "a") as f:
            f.write("%s fim do drag via %s\n" % (time.strftime("%H:%M:%S"), why))
    except Exception:
        pass
    _finalize(nid, mode)


def _finalize(nid, mode):
    if not os.path.exists(FLAG):
        return
    sx = sy = 0
    try:
        parts = open(FLAG).read().split()
        if len(parts) >= 4:
            sx, sy = int(parts[2]), int(parts[3])
    except Exception:
        pass
    if mode != "tiled":
        os.unlink(FLAG)
        return
    root = tree_root()
    if not root:
        os.unlink(FLAG)
        return
    rect = rect_of(nid, root)
    if rect:
        cx = rect["x"] + rect["width"] // 2
        cy = rect["y"] + rect["height"] // 2
        tgt, tws = leaf_containing(cx, cy, root, exclude=nid)
    else:
        tgt = None
    cmd("[con_id=%d] floating disable" % nid)
    os.unlink(FLAG)
    if not tgt or tgt.get("fullscreen_mode"):
        return
    # sem movimento real (ex.: MOD+clique seco) NAO reordena
    if rect and sx and (abs(cx - sx) + abs(cy - sy)) < SWAP_MIN:
        return
    root = tree_root()
    if not root:
        return
    tid = tgt.get("id")
    t2ws = _node_ws(tid, root)
    n2ws = _node_ws(nid, root)
    if not t2ws or not n2ws or t2ws.get("id") != n2ws.get("id"):
        return
    if is_floating(tid, root):
        return
    cmd("[con_id=%d] focus; swap container with con_id %d" % (nid, tid))


def start():
    if os.path.exists(FLAG):
        return
    root = tree_root()
    if not root:
        return
    node, flo = focus_leaf(root)
    if not node or node.get("fullscreen_mode"):
        return
    nid = node.get("id")
    mode = "floating" if flo else "tiled"
    rc = rect_of(nid, root)
    sx = (rc.get("x", 0) + rc.get("width", 0) // 2) if rc else 0
    sy = (rc.get("y", 0) + rc.get("height", 0) // 2) if rc else 0
    if mode == "tiled":
        cmd("[con_id=%d] floating enable" % nid)
    with open(FLAG, "w") as f:
        f.write("%d %s %d %d\n" % (nid, mode, sx, sy))
    pid = os.fork()
    if pid == 0:
        # filho vira root p/ ler o evdev (wheel tem NOPASSWD)
        os.execv("/usr/bin/sudo", ["sudo", "-n", sys.executable, SCRIPT,
                                   "follow", str(nid), mode])


def end():
    if not os.path.exists(FLAG):
        return
    open(STOP, "w").close()
    for _ in range(80):
        p = subprocess.run(["pgrep", "-f", "drag-window.py follow"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if p.returncode != 0:
            break
        time.sleep(0.025)
    if os.path.exists(STOP):
        os.unlink(STOP)


def help_():
    print(__doc__)
    sys.exit(0)


def main():
    act = sys.argv[1] if len(sys.argv) > 1 else "help"
    if act == "start":
        start()
    elif act == "end":
        end()
    elif act == "follow":
        if len(sys.argv) >= 4:
            follow(int(sys.argv[2]), sys.argv[3])
        else:
            help_()
    else:
        help_()


if __name__ == "__main__":
    main()