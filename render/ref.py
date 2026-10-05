# Independent check of the renderer.
# Runs the render_cli build in Ripes for each state, and compares every printed
# frame with a facelet-level cube that is turned geometrically (no orientation
# arithmetic, no tables from solver.c), drawn with the same net layout.
# Usage (from the repository root): RIPES=/path/to/Ripes python3 render/ref.py STATE...
import os, subprocess, sys
POS={0:(-1,1,1),1:(1,1,1),2:(1,-1,1),3:(-1,-1,1),4:(1,1,-1),5:(1,-1,-1),6:(-1,-1,-1),7:(-1,1,-1)}
INV={v:k for k,v in POS.items()}
NORMAL={0:(1,0,0),1:(0,0,-1),2:(0,-1,0)}
def rot(v,n):
    cx=(n[1]*v[2]-n[2]*v[1], n[2]*v[0]-n[0]*v[2], n[0]*v[1]-n[1]*v[0]); d=sum(a*b for a,b in zip(n,v))
    return tuple(-cx[i]+n[i]*d for i in range(3))
def sd(p,ax):
    v=[0,0,0]; v[ax]=POS[p][ax]; return tuple(v)
def solved():
    return {(p,ax):(ax,POS[p][ax]) for p in POS for ax in range(3)}
def turn(F,f):
    n=NORMAL[f]; G=dict(F)
    for p,c in POS.items():
        if sum(a*b for a,b in zip(n,c))!=1: continue
        q=INV[rot(c,n)]
        for ax in range(3):
            d=rot(sd(p,ax),n); G[(q,[i for i in range(3) if d[i]][0])]=F[(p,ax)]
    return G
def face_of(ax,s): return {(0,1):'R',(0,-1):'L',(1,1):'U',(1,-1):'D',(2,1):'F',(2,-1):'B'}[(ax,s)]
ORIG={'U':(9,2),'L':(0,9),'F':(9,9),'R':(18,9),'B':(27,9),'D':(9,16)}
LET={'U':'W','D':'Y','F':'G','B':'B','R':'R','L':'O'}
def cell(f,c):
    x,y,z=c
    return {'F':(x>0,y<0),'R':(z<0,y<0),'B':(x<0,y<0),'L':(z>0,y<0),'U':(x>0,z>0),'D':(x>0,z<0)}[f]
def frame(F):
    g=[['.']*35 for _ in range(25)]
    for (p,ax),col in F.items():
        c=POS[p]; f=face_of(ax,c[ax]); cc,rr=cell(f,c); ox,oy=ORIG[f]
        for dy in range(3):
            for dx in range(4): g[oy+3*int(rr)+dy][ox+4*int(cc)+dx]=LET[face_of(*col)]
    return "\n".join("".join(r) for r in g)
def apply(F,name):
    f="RBD".index(name[0])
    for _ in range({"":1,"2":2,"'":3}[name[1:]]): F=turn(F,f)
    return F
inv={"R":"R'","R'":"R","R2":"R2","B":"B'","B'":"B","B2":"B2","D":"D'","D'":"D","D2":"D2"}
ok_all=True
for state in sys.argv[1:]:
    src=subprocess.run(["tools/build.sh","render_cli",state],capture_output=True,text=True).stdout.strip()
    out=subprocess.run([os.environ["RIPES"],"--mode","cli","--src",src,"-t","asm","--proc","RV32_ISS"],capture_output=True,text=True).stdout
    lines=[l for l in out.split("\n") if len(l)==35 and set(l)<=set(".WYGBRO?")]
    frames=["\n".join(lines[i:i+25]) for i in range(0,len(lines),25)]
    sl=[l for l in out.split("\n") if l and len(l)!=35 and set(l)<=set("RBD2' ")]
    sol=sl[0].split() if sl else []
    F=solved()
    for mv in reversed(sol): F=apply(F,inv[mv])     # the scramble the solution undoes
    refs=[frame(F)]
    for mv in sol: F=apply(F,mv); refs.append(frame(F))
    ok=frames==refs and refs[-1]==frame(solved())
    ok_all&=ok
    print(state, "moves", len(sol), "frames", len(frames), "match", ok)
print("ALL OK" if ok_all else "MISMATCH")
