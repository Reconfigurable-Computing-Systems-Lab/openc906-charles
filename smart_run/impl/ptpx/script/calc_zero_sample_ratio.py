import glob, os, pandas as pd

paths = sorted(glob.glob('/dfs/usrhome/jjiangan/github/openc906-charles-imp/smart_run/impl/ptpx/db/*_func.pkl'))
print(f'found {len(paths)} _func.pkl file(s)')
for p in paths:
    df = pd.read_pickle(p)
    feat = df.drop(columns=[c for c in ('time_ps',) if c in df.columns])
    n = len(feat)
    if n == 0:
        print(f'{os.path.basename(p):40s} rows=0  zero_rows=0  ratio=NA')
        continue
    # A row counts as "all zero" only if every feature value is exactly 0.
    # NaN values are treated as not-zero (filled with 1 before the comparison).
    zero_mask = (feat.fillna(1) == 0).all(axis=1)
    z = int(zero_mask.sum())
    print(f'{os.path.basename(p):40s} rows={n:<8d} zero_rows={z:<8d} ratio={z/n:.6f}')
