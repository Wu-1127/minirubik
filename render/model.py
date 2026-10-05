import itertools, random
# Corner positions (README): x right, y up, z front
POS = {0:(-1,1,1),1:(1,1,1),2:(1,-1,1),3:(-1,-1,1),4:(1,1,-1),5:(1,-1,-1),6:(-1,-1,-1),7:(-1,1,-1)}
INV = {v:k for k,v in POS.items()}
source=[[1,4,2,0,3,5,6],[0,1,2,4,5,6,3],[0,2,5,3,1,4,6]]
twist=[[1,2,0,2,1,0,0],[0,0,0,1,2,1,2],[0,0,0,0,0,0,0]]
NORMAL={0:(1,0,0),1:(0,0,-1),2:(0,-1,0)}  # R, B, D
def rot(v,n):   # clockwise 90 deg seen from outside along normal n = rotation by -90 about n
    # rotation by angle t about unit axis n: v cos t + (n x v) sin t + n (n.v)(1-cos t); t=-90 -> -(n x v) + n(n.v)
    cx=(n[1]*v[2]-n[2]*v[1], n[2]*v[0]-n[0]*v[2], n[0]*v[1]-n[1]*v[0])
    d=sum(a*b for a,b in zip(n,v))
    return tuple(-cx[i]+n[i]*d for i in range(3))
# 1) check permutation: geometric clockwise turn vs source
for f in range(3):
    n=NORMAL[f]; dest_from={}
    for pidx,c in POS.items():
        if sum(a*b for a,b in zip(n,c))==1:
            dest_from[INV[rot(c,n)]]=pidx
    ok=all(dest_from.get(d+1,d+1)==source[f][d]+1 for d in range(7))
    print("face",f,"perm matches clockwise:",ok)
# stickers: (position, axis) ; axis 0=x,1=y,2=z
def sticker_dir(p,axis):
    c=POS[p]; v=[0,0,0]; v[axis]=c[axis]; return tuple(v)
def cyc(p):
    # axes in clockwise order seen from outside the corner, starting with y (U/D)
    c=POS[p]; axes=[1,2,0]  # y,z,x candidate; check handedness
    a=sticker_dir(p,1); b=sticker_dir(p,2); cc=sticker_dir(p,0)
    # triple product sign of (a,b,cc) relative to outward diagonal decides orientation
    det=a[0]*(b[1]*cc[2]-b[2]*cc[1])-a[1]*(b[0]*cc[2]-b[2]*cc[0])+a[2]*(b[0]*cc[1]-b[1]*cc[0])
    return [1,2,0] if det<0 else [1,0,2]
# facelet-level model: color at each (pos, axis)
def solved_facelets():
    F={}
    for p,c in POS.items():
        for ax in range(3):
            F[(p,ax)]=('x',ax,c[ax])   # face id = (axis, sign)
    return F
def turn_facelets(F,f):
    n=NORMAL[f]; G=dict(F)
    for p,c in POS.items():
        if sum(a*b for a,b in zip(n,c))!=1: continue
        q=INV[rot(c,n)]
        for ax in range(3):
            d=rot(sticker_dir(p,ax),n); nax=[i for i in range(3) if d[i]!=0][0]
            G[(q,nax)]=F[(p,ax)]
    return G
def quarter(p,o,f):
    np=[p[source[f][i]] for i in range(7)]; no=[(o[source[f][i]]+twist[f][i])%3 for i in range(7)]
    return np,no
# rendering rule candidate: cubie c (0..7) has solved colors at its home position in cyclic order;
# at position i with orientation o, slot k shows cubie sticker (k - s*o) mod 3, s in {+1,-1}
def render(p,o,s,order):
    R={}
    cub=[0]+[x+1 for x in p]; ori=[0]+list(o)
    for i in range(8):
        c=cub[i]; home=order(c); here=order(i)
        for k in range(3):
            R[(i,here[k])]=('x',home[(k - s*ori[i])%3],POS[c][home[(k - s*ori[i])%3]])
    return R
for s in (1,-1):
  for name,order in (("cw",cyc),("ccw",lambda p:[cyc(p)[0],cyc(p)[2],cyc(p)[1]])):
    good=True; random.seed(1)
    for trial in range(300):
        p=list(range(7)); o=[0]*7; F=solved_facelets()
        for step in range(random.randint(1,15)):
            f=random.randrange(3); p,o=quarter(p,o,f); F=turn_facelets(F,f)
        if render(p,o,s,order)!=F: good=False; break
    print("s",s,name,good)
