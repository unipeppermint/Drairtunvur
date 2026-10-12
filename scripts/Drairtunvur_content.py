"""Authored puzzle families with explicit, replayable construction plans.
Uses the existing rules and 8x8 board. No procedural generation in the app.
"""
import json, random
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def cell(p): return dict(row=p[0],col=p[1])
def line(r): return {(r,c) for c in range(8)}
def column(c): return {(r,c) for r in range(8)}
def reachable(board,source):
    todo=[source] if source in board else []; seen=set(todo)
    for r,c in todo:
        for p in [(r-1,c),(r+1,c),(r,c-1),(r,c+1)]:
            if p in board and p not in seen: seen.add(p); todo.append(p)
    return seen

def author(kind, seed, chapter):
    rng=random.Random(seed)
    steps=[]; targets=[]
    if kind in ('cascade','relay','reservoir'):
        rows=sorted(rng.sample(range(2,7), 3 if kind=='reservoir' or chapter==3 else 2))
        source=(0,0); initial={(r,0) for r in range(max(rows)+1)}
        gaps={}
        for r in rows:
            start=rng.choice([1,2,3,4]); gap={(r,start),(r,start+1),(r,6),(r,7)}
            gaps[r]=gap; initial |= line(r)-gap
            targets.append(((r,7),1))
        order=rows[::-1] if kind!='relay' else rows
        for i,r in enumerate(order):
            if kind=='relay' and i: steps.extend([[(old,0)] for old in order[i-1:i]])
            gap=gaps[r]; left=sorted(p for p in gap if p[1]<6)
            steps += [left,[(r,6),(r,7)]]
        lesson='cascade' if kind!='relay' else 'relay'
    elif kind=='cross':
        r=rng.choice([3,4,5]); c=rng.choice([3,4,5]); source=(r,0)
        initial=line(r)|column(c)
        gaps=[[(r,0),(r,1)],[(0,c),(1,c)],[(r,c),(r,c+1)]]
        # Optional bent branch must be prepared before the shared crossing pulse.
        tip=(r-2,c+2); initial.add(tip); targets=[((r,7),1),((7,c),1),(tip,1)]
        steps=[[(r-1,c+1),(r-1,c+2)]]+gaps
        initial -= set(sum(gaps,[])); lesson='cross'
    elif kind=='switchback':
        r=rng.choice([2,3,4]); c=rng.choice([3,4,5]); source=(0,0)
        initial=line(r)|column(c)|{(a,0) for a in range(r)}|{(0,b) for b in range(c)}
        # First pulse charges the lower light through the row; the second uses the column.
        initial -= {(r,1),(r,2),(0,c)}
        targets=[((r,7),1),((7,c),2)]
        steps=[[(r,1),(r,2)],[(0,c)],[(r,c)]]; lesson='switchback'
    elif kind=='double':
        r=rng.choice([2,3,4,5]); source=(r,0)
        initial=line(r)|line(r+1)
        gaps=[[(r,1),(r+1,1)],[(r,4),(r+1,4)],[(r,6),(r+1,6)]]
        initial-=set(sum(gaps,[]));targets=[((r,7),1),((r+1,7),1)]
        steps=gaps; lesson='cross'
        if chapter==3:
            targets=[(p,2) for p,_ in targets]
            steps += [[(a,b) for a in (r,r+1) for b in (c,c+1)] for c in range(0,8,2)]
            lesson='double-rebuild'
    else: raise ValueError(kind)
    # Board isometry preserves rules; use all eight orientations without changing controls.
    mode=seed%8
    def transform(p):
        r,c=p
        if mode&1: c=7-c
        if mode&2: r=7-r
        if mode&4: r,c=c,r
        return r,c
    initial={transform(p) for p in initial}; source=transform(source)
    targets=[(transform(p),n) for p,n in targets]
    steps=[[transform(p) for p in s] for s in steps]
    return initial,source,targets,steps,lesson

def build(kind,seed,ch,n,id):
    initial,source,targets,steps,lesson=author(kind,seed,ch)
    board=set(initial);energy=[0]*len(targets);pulses=[]
    for i,coords in enumerate(steps):
        assert coords and not board.intersection(coords),(kind,seed,i,'overlap')
        assert len(reachable(set(coords),coords[0]))==len(coords),(kind,seed,i,'disconnected piece')
        board.update(coords); rows=[r for r in range(8) if line(r)<=board];cols=[c for c in range(8) if column(c)<=board]
        if rows or cols:
            linked=reachable(board,source)
            energy=[min(cap,e+(p in linked)) for e,(p,cap) in zip(energy,targets)]
            board -= set().union(*(line(r) for r in rows),*(column(c) for c in cols))
            pulses.append(dict(rows=rows,columns=cols))
        won=all(e==cap for e,(_,cap) in zip(energy,targets))
        assert not won or i==len(steps)-1,(kind,seed,'early win')
    assert won,(kind,seed,'not won',energy)
    def piece(coords):
        mr=min(r for r,c in coords);mc=min(c for r,c in coords)
        normalized=sorted((r-mr,c-mc) for r,c in coords)
        return dict(id=';'.join(f'{r},{c}' for r,c in normalized),cells=[cell(p) for p in normalized])
    rng=random.Random(seed+9000);batches=[];solution=[]
    for i in range(0,len(steps),3):
        batch=[piece([(0,0),(0,1),(1,0),(1,1)]) for _ in range(3)]
        slots=list(range(3));rng.shuffle(slots)
        for coords,slot in zip(steps[i:i+3],slots):
            batch[slot]=piece(coords)
            solution.append(dict(slot=slot,anchor=cell((min(r for r,c in coords),min(c for r,c in coords)))))
        batches.append(batch)
    batches.append([piece([(0,0)]),piece([(0,0),(0,1)]),piece([(0,0),(1,0),(1,1)])])
    result=dict(id=id,chapter=ch,number=n,schemaVersion=1,contentVersion=2,rulesVersion=1,boardSize=8,
      initialOccupiedCells=[cell(p) for p in sorted(initial)],sourceEntry=cell(source),
      targets=[dict(id=chr(65+i),cell=cell(p),capacity=cap,initialEnergy=0) for i,(p,cap) in enumerate(targets)],
      pieceBatches=batches,moveLimit=len(steps)+(3 if ch==1 else 2),referenceSolution=solution,lesson=lesson)
    return result,pulses

def main():
    old=json.loads((ROOT/'verification/Drairtunvur-levels-v1.json').read_text())
    families=['cascade','double','cross','relay','switchback','reservoir']
    levels=[];report=[]
    for previous in old:
        ch,n=previous['chapter'],previous['number']
        if ch==1 and n<=5: levels.append(previous);continue
        kind=families[(n-6 if ch==1 else n+ch)%len(families)]
        result,pulses=build(kind,ch*100+n,ch,n,previous['id'])
        levels.append(result);report.append(dict(id=result['id'],family=kind,pulses=pulses))
    # Independent daily catalogue. Deduplicate actual starting boards + targets + source.
    daily=[];seen=set();seed=0
    campaign_signatures={json.dumps([l[k] for k in ['initialOccupiedCells','sourceEntry','targets']],sort_keys=True) for l in levels}
    while len(daily)<365:
        kind=families[seed%6]; ch=1+seed%3
        result,pulses=build(kind,seed,ch,5,f'daily-catalog.{len(daily)+1:03}')
        signature=json.dumps([result[k] for k in ['initialOccupiedCells','sourceEntry','targets']],sort_keys=True)
        if signature not in seen and signature not in campaign_signatures:
            seen.add(signature);daily.append(result)
        seed+=1
        assert seed<100000,'Insufficient distinct authored layouts'
    resource=ROOT/'Drairtunvur/Resources'
    for name,data in [('levels',levels),('Drairtunvur-daily-levels',daily)]:
        (resource/f'{name}.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    (ROOT/'LightworksUITests/ReferenceSolutions.json').write_text(json.dumps([dict(id=l['id'],moves=l['referenceSolution']) for l in levels[:10]],indent=2)+'\n')
    import datetime
    day='2026-10-12';ordinal=(datetime.date.fromisoformat(day)-datetime.date(1970,1,1)).days
    selected=daily[ordinal%len(daily)]
    (ROOT/'LightworksUITests/DailyReferenceSolution.json').write_text(json.dumps(dict(day=day,moveLimit=selected['moveLimit'],moves=selected['referenceSolution']),indent=2)+'\n')
    (ROOT/'verification/Drairtunvur-content-v2.json').write_text(json.dumps(dict(campaign=report,dailyCount=len(daily),dailyDistinctBoards=len(seen)),indent=2)+'\n')
    print(f'45 campaign levels; {len(report)} redesigned. {len(daily)} distinct daily boards.')
if __name__=='__main__': main()
