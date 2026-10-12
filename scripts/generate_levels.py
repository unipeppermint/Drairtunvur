"""Deterministic authored templates; every output carries an executable solution.
No runtime generation. Numbered variants change topology, gaps, piece order and charge budget.
"""
import json, random
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def cell(r,c): return {'row':r,'col':c}
def piece(coords):
    r=min(x[0] for x in coords); c=min(x[1] for x in coords)
    coords=sorted((a-r,b-c) for a,b in coords)
    return {'id':';'.join(f'{a},{b}' for a,b in coords),'cells':[cell(a,b) for a,b in coords]}
def build(ch,n):
    rng=random.Random(ch*100+n)
    r=2+(n%3); source=(r,0); occupied=set(); steps=[]; targets=[]
    # Main bus has three fixed segments. Later chapters require rebuilding it.
    cuts=[[2,3,3],[3,2,3],[3,3,2],[2,2,4]][n%4]
    segments=[]; col=0
    for length in cuts:
        segments.append([(r,c) for c in range(col,col+length)]); col+=length
    branch_cols=([2+n%4] if ch==1 and n<=5 else [1+n%2,5+n%2])
    if ch==3 and n>=10: branch_cols=[1,4,6]
    capacity=2 if ch==3 else 1
    if n==1 and ch==1:
        occupied.update((r,c) for c in range(6)); steps=[[(r,6),(r,7)]]
        targets=[{'id':'A','cell':cell(r,3),'capacity':1,'initialEnergy':0}]
    else:
        # Branches rise/fall from the bus; a missing bridge must be laid before pulsing.
        for i,c in enumerate(branch_cols):
            direction=-1 if i%2==0 else 1
            tip=(r+2*direction,c); bridge=(r+direction,c)
            occupied.add(tip)
            targets.append({'id':chr(65+i),'cell':cell(*tip),'capacity':capacity,'initialEnergy':0})
            if ch==1 and n<5: occupied.add(bridge)
            elif ch>=2 and n%3==0:
                # A bent branch adds a choice of anchor and a persistent side cell.
                side=(r+direction,c-1)
                steps.append([bridge,side])
            else: steps.append([bridge])
        # Early levels have partial prebuilt buses, later levels build all three pieces.
        prebuilt=2 if ch==1 and n<=3 else (1 if ch==1 and n<=9 else 0)
        for seg in segments[:prebuilt]: occupied.update(seg)
        order=list(range(prebuilt,len(segments)))
        rng.shuffle(order)
        steps.extend(segments[i] for i in order)
        if capacity==2:
            # Bus disappears after first pulse, while charged branch targets remain.
            order=list(range(3)); rng.shuffle(order)
            steps.extend(segments[i] for i in order)
        # Sparse islands create usable but misleading placements without implicit clears.
        for _ in range(n//4):
            p=(rng.choice([0,7]),rng.randrange(1,7))
            occupied.add(p)
    # Reflect alternating boards to teach right/top/bottom entry without rotation controls.
    def transform(p):
        a,b=p
        if n%2==0: b=7-b
        if n>=11: a,b=b,a
        return a,b
    source=transform(source); occupied={transform(p) for p in occupied}
    for t in targets: t['cell']=cell(*transform((t['cell']['row'],t['cell']['col'])))
    steps=[[transform(p) for p in group] for group in steps]
    batches=[]; solution=[]
    for start in range(0,len(steps),3):
        group=steps[start:start+3]; slots=list(range(3))
        if n>2: rng.shuffle(slots)
        batch=[None]*3
        for i,coords in enumerate(group):
            slot=slots[i]; batch[slot]=piece(coords)
            solution.append({'slot':slot,'anchor':cell(min(x[0] for x in coords),min(x[1] for x in coords))})
        for i in range(3):
            if batch[i] is None: batch[i]=piece([(0,0),(0,1),(1,0),(1,1)] if i%2 else [(0,0),(1,0),(2,0)])
        batches.append(batch)
    # Spare fixed batch gives room for recovery, but every move still matters.
    batches.append([piece([(0,0)]),piece([(0,0),(0,1)]),piece([(0,0),(1,0),(1,1)])])
    return dict(id=f'{ch}-{n:02}',chapter=ch,number=n,schemaVersion=1,contentVersion=1,rulesVersion=1,boardSize=8,initialOccupiedCells=[cell(*p) for p in sorted(occupied)],sourceEntry=cell(*source),targets=targets,pieceBatches=batches,moveLimit=len(steps)+(0 if n==1 else (3 if ch<3 else 2)),referenceSolution=solution,lesson='first' if ch==1 and n==1 else ('rebuild' if ch==3 else ('branches' if len(targets)>1 else 'connect')))
levels=[build(c,n) for c in range(1,4) for n in range(1,16)]
(ROOT/'Drairtunvur/Resources/levels.json').write_text(json.dumps(levels,ensure_ascii=False,indent=2)+'\n')
print(f'Wrote {len(levels)} levels, {sum(len(l["referenceSolution"]) for l in levels)} reference moves')
