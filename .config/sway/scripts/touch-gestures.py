#!/usr/bin/env python3
"""Daemon de gestos de toque -> sway (Positivo C8128E / FTSC1000).

Gestos (v3):
  - Tap (toque rapido e parado) .... clique esquerdo no ponto tocado
  - Segurar 1 dedo parado (0.6s) ... clique direito no ponto tocado
- Arrastar com 1 dedo ......... troca a janela de lugar no tiling
                                    (swap p/ o vizinho; se a janela ja era
                                    flutuante, move ela livremente)
                                    precisa segurar ~1.0s antes de arrastar
                                    (senão é scroll da página, nao swap)
  - Deslizar 2 dedos L/R ........ troca de workspace (esq=next, dir=prev)
  - fullscreen por toque ........ removido (nao funcionava bem)

Precisa ler /dev/input/eventX (roda root automaticamente via sudo -n).
"""
import os
import re
import sys
import json
import glob
import time
import fcntl
import subprocess
import traceback
from evdev import InputDevice, ecodes

LOCK_FD = None
LOG_FILE = "/tmp/sway-touch-gestures.log"

REQUIRED_NAME = "FTSC1000:00 2808:509C"
PID_FILE = "/tmp/sway-touch-gestures.pid"
SCREEN_W, SCREEN_H = 1366, 768

# Limiares (px por gesto, na tela 1366x768)
MOVE_STEP = 16          # passo de "move" durante o arraste
DRAG_ARM = 14           # movimento minimo p/ considerar arraste
DRAG_HOLD = 1.0         # segurar antes de arrastar (evita swap ao rolar pagina)
SWIPE_TH = 60           # deslocamento p/ swipe
STEP_MIN_MS = 28        # throttle entre comandos
ACTION_COOLDOWN = 0.40  # debounce de workspace
SWAP_DIST = 100         # deslocamento minimo p/ ativar o swap no drag
TAP_TIME = 0.25         # max duracao p/ contar como tap (clique esquerdo)
LONG_PRESS = 0.60       # min duracao p/ segurar parado = clique direito
TAP_MOVE = 12           # movimento max p/ contar como toque parado

# Daemon do ydotool (user service, socket DGRAM em /run/user/<uid>/).
# NAO fixa uid: descoberto por glob (aguenta re-exec via sudo -n e outra conta).
YDOTOOL_SOCK = None


def find_ydotool_sock():
    for s in sorted(glob.glob("/run/user/*/.ydotool_socket")):
        return s
    return None


def find_device():
    # via /proc/bus/input/devices (lêvel sem grupo input)
    cur = {}
    try:
        for line in open("/proc/bus/input/devices"):
            if line.startswith("N:"):
                cur["name"] = line.split("=", 1)[1].strip().strip('"')
            elif line.startswith("H:"):
                m = re.search(r"event(\d+)", line)
                cur["ev"] = "event" + m.group(1) if m else None
            elif line.startswith("I:"):
                if cur.get("name") == REQUIRED_NAME and cur.get("ev"):
                    return "/dev/input/" + cur["ev"]
                cur = {}
    except OSError:
        pass
    return None


def acquire_lock():
    global LOCK_FD
    lock_path = "/tmp/sway-touch-gestures.lock"
    LOCK_FD = open(lock_path, "w")
    try:
        fcntl.flock(LOCK_FD, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        sys.exit(0)  # ja existe outra instancia
    with open(PID_FILE, "w") as f:
        f.write(str(os.getpid()))


def find_socket():
    for s in sorted(glob.glob("/run/user/*/sway-ipc.*.sock")):
        return s
    return None


def log(msg):
    try:
        with open(LOG_FILE, "a") as f:
            f.write(time.strftime("%H:%M:%S ") + str(msg) + "\n")
    except OSError:
        pass


def sway(cmd):
    sock = find_socket()
    env = dict(os.environ)
    env["SWAYSOCK"] = sock
    try:
        subprocess.run(["swaymsg", cmd], env=env, timeout=2,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass


def sway_json(*args):
    sock = find_socket()
    env = dict(os.environ)
    env["SWAYSOCK"] = sock
    try:
        out = subprocess.check_output(["swaymsg"] + list(args), env=env, timeout=2)
        return json.loads(out)
    except Exception:
        return None


def click(button, x, y):
    global YDOTOOL_SOCK
    sway("seat seat0 cursor set %d %d" % (int(x), int(y)))
    time.sleep(0.05)
    if YDOTOOL_SOCK is None:
        YDOTOOL_SOCK = find_ydotool_sock()
    if YDOTOOL_SOCK is None:
        log("ydotool socket nao encontrado (daemon rodando?)")
        return
    env = dict(os.environ)
    env["YDOTOOL_SOCKET"] = YDOTOOL_SOCK
    subprocess.run(["ydotool", "click", button], env=env, timeout=2,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


# Apps que convertem toque em clique por conta propria (Chromium/Gecko).
# Nesse caso o tap do daemon NAO deve clicar, senao vira clique duplo.
BROWSERS = {"floorp", "org.mozilla.floorp", "firefox", "org.mozilla.firefox",
            "chromium", "google-chrome", "brave", "librewolf", "zen",
            "waterfox", "microsoft-edge", "vivaldi", "opera",
            "epiphany", "org.gnome.Epiphany"}


def browser_focused():
    tree = sway_json("-t", "get_tree")
    if not tree:
        return False
    if isinstance(tree, list):
        tree = tree[0] if tree else None
    if not tree:
        return False

    def find(n):
        if n.get("focused"):
            app = (n.get("app_id") or n.get("name") or "").lower()
            return app in BROWSERS
        for c in n.get("nodes", []) + n.get("floating_nodes", []):
            r = find(c)
            if r:
                return True
        return False

    return find(tree)


def tree_pairs(tree):
    pairs = []

    def walk(n, ws, is_float):
        if n.get("type") == "workspace":
            ws = n
        for c in n.get("nodes", []):
            walk(c, ws, False)
        for c in n.get("floating_nodes", []):
            walk(c, ws, True)
        pairs.append((ws, n, is_float))

    walk(tree, None, False)
    return pairs


def focused_con(tree):
    for ws, n, is_float in tree_pairs(tree):
        if n.get("focused"):
            return ws, n, is_float
    return None, None, False


def focused_is_floating():
    tree = sway_json("-t", "get_tree")
    if not tree:
        return False
    _, _, is_float = focused_con(tree)
    return is_float


def do_swap(dx, dy):
    tree = sway_json("-t", "get_tree")
    if not tree:
        log("  -> swap: sem tree (erro)")
        return False
    ws, node, is_float = focused_con(tree)
    if node is None or is_float or node.get("fullscreen_mode"):
        return False
    fx = node["rect"]["x"]
    fy = node["rect"]["y"]
    fx2 = fx + node["rect"]["width"]
    fy2 = fy + node["rect"]["height"]
    as_vertical = abs(dx) < abs(dy)
    best, bd = None, float("inf")
    for ws2, c, c_float in tree_pairs(tree):
        if ws is None or ws2 is None or ws2.get("id") != ws.get("id"):
            continue
        if c.get("id") == node.get("id") or c_float or c.get("fullscreen_mode"):
            continue
        r = c.get("rect")
        if not r:
            continue
        x, y, w, h = r["x"], r["y"], r["width"], r["height"]
        x2, y2 = x + w, y + h
        if as_vertical:
            if dy < 0 and y2 <= fy + 1:
                ov = min(fx2, x2) - max(fx, x)
                if ov > 0 and fy - y2 < bd:
                    bd, best = fy - y2, c
            elif dy > 0 and y >= fy2 - 1:
                ov = min(fx2, x2) - max(fx, x)
                if ov > 0 and y - fy2 < bd:
                    bd, best = y - fy2, c
        else:
            if dx < 0 and x2 <= fx + 1:
                ov = min(fy2, y2) - max(fy, y)
                if ov > 0 and fx - x2 < bd:
                    bd, best = fx - x2, c
            elif dx > 0 and x >= fx2 - 1:
                ov = min(fy2, y2) - max(fy, y)
                if ov > 0 and x - fx2 < bd:
                    bd, best = x - fx2, c
    if best is not None:
        sway("swap container with con_id %d" % best["id"])
        log("  -> swap com '%s' (%s)" % (best.get("name") or best.get("app_id"),
                                         "vert" if as_vertical else "horiz"))
        return True
    log("  -> swap: vizinho nao encontrado")
    return False


def main():
    path = find_device()
    if path is not None:
        try:
            InputDevice(path).close()
        except OSError:
            path = None  # sem permissao -> tenta com root
    if path is None and os.geteuid() != 0:
        os.execv("/usr/bin/sudo",
                 ["sudo", "-n", sys.executable, os.path.abspath(__file__)])
    path = find_device()
    if path is None:
        print("touchscreen nao encontrado", file=sys.stderr)
        sys.exit(1)
    acquire_lock()

    dev = InputDevice(path)
    abs_x = dev.absinfo(ecodes.ABS_MT_POSITION_X)
    abs_y = dev.absinfo(ecodes.ABS_MT_POSITION_Y)
    log("daemon iniciado em %s (pid %d, euid %d)" % (path, os.getpid(), os.geteuid()))

    slots = {}          # slot -> (tracking_id, x_raw, y_raw) | None
    current_slot = 0
    last_cmd = 0.0
    last_action = 0.0

    g = {"gest": None, "max_fingers": 0, "t0": 0.0,
         "first": None, "prev": None,
         "armed": False, "floater": False,
         "dispx": 0.0, "dispy": 0.0, "dist0": None, "dist": None,
         "pending_dx": 0.0, "pending_dy": 0.0}

    def norm(x_raw, y_raw):
        x = (x_raw - abs_x.min) * SCREEN_W / max(1, abs_x.max - abs_x.min)
        y = (y_raw - abs_y.min) * SCREEN_H / max(1, abs_y.max - abs_y.min)
        return x, y

    def active():
        out = []
        for s, v in slots.items():
            if v is not None and v[0] >= 0:
                x, y = norm(v[1], v[2])
                out.append((x, y))
        return sorted(out)

    def reset():
        g.update(dict(gest=None, max_fingers=0, t0=0.0, first=None, prev=None,
                      armed=False, floater=False, dispx=0.0, dispy=0.0,
                      dist0=None, dist=None, pending_dx=0.0, pending_dy=0.0))

    def end_gesture():
        nonlocal last_action
        now = time.monotonic()
        log("  fim gesto: %d dedo(s), tx=%.1f ty=%.1f" %
            (g["max_fingers"], g["dispx"], g["dispy"]))
        if g["max_fingers"] == 1:
            log("  -> fim drag: dx=%.1f dy=%.1f floater=%s" %
                (g["dispx"], g["dispy"], g["floater"]))
            if g["armed"]:
                if not g["floater"] and (abs(g["dispx"]) >= SWAP_DIST or
                                         abs(g["dispy"]) >= SWAP_DIST):
                    do_swap(g["dispx"], g["dispy"])
            else:
                x, y = g["first"][0]
                moved = (g["dispx"] ** 2 + g["dispy"] ** 2) ** 0.5
                duration = now - g["t0"]
                if moved < TAP_MOVE and duration < TAP_TIME:
                    if browser_focused():
                        log("  -> tap: navegador (clique nativo) @%.0f,%.0f (%.2fs)" %
                            (x, y, duration))
                    else:
                        click("0xC0", x, y)
                        log("  -> tap = clique esquerdo @%.0f,%.0f (%.2fs)" % (x, y, duration))
                elif moved < TAP_MOVE and duration >= LONG_PRESS:
                    click("0xC1", x, y)
                    log("  -> segurar = clique direito @%.0f,%.0f (%.2fs)" % (x, y, duration))
        elif g["max_fingers"] >= 2 and (now - last_action) > ACTION_COOLDOWN:
            dx, dy = g["dispx"], g["dispy"]
            if abs(dx) >= SWIPE_TH and abs(dx) >= 2 * abs(dy):
                sway("workspace next" if dx < 0 else "workspace prev")
                last_action = now
                log("  -> workspace %s" % ("next" if dx < 0 else "prev"))
        reset()

    for event in dev.read_loop():
        if event.type != ecodes.EV_ABS:
            if event.type == ecodes.EV_SYN and event.code == ecodes.SYN_REPORT:
                try:
                    fingers = active()
                    now = time.monotonic()
                    if not fingers:
                        if g["gest"]:
                            end_gesture()
                        continue

                    if g["gest"] is None:
                        if len(fingers) <= 2:
                            g["gest"] = True
                            g["t0"] = now
                            g["max_fingers"] = len(fingers)
                            g["first"] = fingers[:]
                            g["prev"] = fingers[:]
                            g["dispx"] = 0.0
                            g["dispy"] = 0.0
                            if len(fingers) == 2:
                                g["dist0"] = dist(fingers[0], fingers[1])
                                g["dist"] = g["dist0"]
                        continue

                    g["max_fingers"] = max(g["max_fingers"], len(fingers))
                    prev = g["prev"]

                    if g["max_fingers"] == 1:
                        x, y = fingers[0]
                        fx, fy = g["first"][0]
                        if not g["armed"]:
                            if (now - g["t0"] >= DRAG_HOLD and
                                    (x - fx) ** 2 + (y - fy) ** 2 > DRAG_ARM ** 2):
                                g["armed"] = True
                                g["floater"] = focused_is_floating()
                                g["pending_dx"] = 0.0
                                g["pending_dy"] = 0.0
                                g["prev"] = [fingers[0]]
                                prev = g["prev"]
                        g["dispx"] = x - fx
                        g["dispy"] = y - fy
                        if (g["armed"] and g["floater"] and
                                now - last_cmd >= STEP_MIN_MS / 1000):
                            # ja flutuante: move livremente; tiled faz swap
                            pdx = x - prev[0][0]
                            pdy = y - prev[0][1]
                            g["pending_dx"] += pdx
                            g["pending_dy"] += pdy
                            mv = []
                            while g["pending_dx"] <= -MOVE_STEP:
                                mv.append("move left %dpx" % MOVE_STEP)
                                g["pending_dx"] += MOVE_STEP
                            while g["pending_dx"] >= MOVE_STEP:
                                mv.append("move right %dpx" % MOVE_STEP)
                                g["pending_dx"] -= MOVE_STEP
                            while g["pending_dy"] <= -MOVE_STEP:
                                mv.append("move up %dpx" % MOVE_STEP)
                                g["pending_dy"] += MOVE_STEP
                            while g["pending_dy"] >= MOVE_STEP:
                                mv.append("move down %dpx" % MOVE_STEP)
                                g["pending_dy"] -= MOVE_STEP
                            g["prev"] = [fingers[0]]
                            if mv:
                                sway("; ".join(mv))
                                last_cmd = now
                    elif len(fingers) == 2:
                        if prev is None or len(prev) < 2:
                            # segundo dedo chegou atrasado: reinicia referencia
                            g["prev"] = fingers[:]
                            prev = g["prev"]
                            if g["dist0"] is None:
                                g["dist0"] = dist(fingers[0], fingers[1])
                            g["dist"] = g["dist0"]
                            continue
                        ax = (fingers[0][0] + fingers[1][0]) / 2
                        ay = (fingers[0][1] + fingers[1][1]) / 2
                        pax = (prev[0][0] + prev[1][0]) / 2
                        pay = (prev[0][1] + prev[1][1]) / 2
                        if g["dist0"] is None:
                            g["dist0"] = dist(fingers[0], fingers[1])
                        g["dispx"] += ax - pax
                        g["dispy"] += ay - pay
                        g["dist"] = dist(fingers[0], fingers[1])
                        g["prev"] = fingers[:]
                    else:
                        pass  # 3+ dedos: ignora
                except Exception:
                    log("=== erro no sync ===\n" + traceback.format_exc())
                    reset()
            continue

        if event.code == ecodes.ABS_MT_SLOT:
            current_slot = event.value
        elif event.code == ecodes.ABS_MT_TRACKING_ID:
            if event.value < 0:
                slots[current_slot] = None
            else:
                slots[current_slot] = (event.value, 0, 0)
        elif event.code == ecodes.ABS_MT_POSITION_X:
            if slots.get(current_slot):
                tid, _, y = slots[current_slot]
                slots[current_slot] = (tid, event.value, y)
        elif event.code == ecodes.ABS_MT_POSITION_Y:
            if slots.get(current_slot):
                tid, x, _ = slots[current_slot]
                slots[current_slot] = (tid, x, event.value)


def dist(a, b):
    return ((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2) ** 0.5


if __name__ == "__main__":
    while True:
        try:
            main()
            break
        except (KeyboardInterrupt, SystemExit):
            break
        except Exception:
            log("=== daemon reiniciando (watchdog) ===\n" + traceback.format_exc())
            time.sleep(1)