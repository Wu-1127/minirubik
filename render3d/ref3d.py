# Bit-exact check of the 3D renderer with animated face turns.
# Runs the render3d_cli build in Ripes and compares every printed frame with
# gen3d.draw(), fed with sticker colours from an independent facelet-level cube
# that is turned geometrically (render/ref.py), not from the assembly's tables.
# Usage (repository root): RIPES=/path/to/Ripes python3 render3d/ref3d.py STATE...
import os, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gen3d
src = open(os.path.join(HERE, '..', 'render', 'ref.py')).read().split("ok_all=True")[0]
flat = {}; exec(src, flat)
LET = {'U':'W','D':'Y','F':'G','B':'B','R':'R','L':'O'}
RGB2L = {0xFFFFFF:'W',0xFFD700:'Y',0x00B000:'G',0x0040FF:'B',0xE00000:'R',0xFF8000:'O',0:'.'}
L2RGB = {v:k for k,v in RGB2L.items()}
NAMES = ["R","R2","R'","B","B2","B'","D","D2","D'"]
CAM_YAW = int(os.environ.get('CAM_YAW', 28))
def colors_of(F):
    col = [0]*24
    for p in range(8):
        for k, ax in enumerate(gen3d.cyc(p)):
            col[p*3+k] = L2RGB[LET[flat['face_of'](*F[(p, ax)])]]
    return col
def text(fb):
    return "\n".join("".join(RGB2L[fb[y*35+x]] for x in range(35)) for y in range(25))
ok_all = True
env = dict(os.environ, CAM_YAW=str(CAM_YAW))
for state in sys.argv[1:]:
    src = subprocess.run(["tools/build.sh","render3d_cli",state], capture_output=True, text=True, env=env).stdout.strip()
    out = subprocess.run([os.environ["RIPES"],"--mode","cli","--src",src,"-t","asm","--proc","RV32_ISS"], capture_output=True, text=True).stdout
    lines = [l for l in out.split("\n") if len(l) == 35 and set(l) <= set(".WYGBRO?")]
    frames = ["\n".join(lines[i:i+25]) for i in range(0, len(lines), 25)]
    sl = [l for l in out.split("\n") if l and len(l) != 35 and set(l) <= set("RBD2' ")]
    sol = sl[0].split() if sl else []
    F = flat['solved']()
    for mv in reversed(sol): F = flat['apply'](F, flat['inv'][mv])
    M = gen3d.camera(CAM_YAW)
    refs = [text(gen3d.draw(M, colors_of(F)))]
    for mv in sol:
        m = NAMES.index(mv); _, _, step, n = gen3d.move_params(m)
        for t in range(1, n):
            refs.append(text(gen3d.draw(M, colors_of(F), m, step*t)))
        F = flat['apply'](F, mv)
        refs.append(text(gen3d.draw(M, colors_of(F))))
    ok = frames == refs and F == flat['solved']()
    bad = [i for i, (a, b) in enumerate(zip(frames, refs)) if a != b]
    ok_all &= ok
    print(state, "moves", len(sol), "frames", len(frames), "/", len(refs), "match", ok, "first bad", bad[:3])
print("ALL OK" if ok_all else "MISMATCH")
