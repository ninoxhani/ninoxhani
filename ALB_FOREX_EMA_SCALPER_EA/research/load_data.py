"""Load Binance XAUUSDT perpetual 1m klines (zip/CSV) into one clean M1 array file.
Usage: python3 -I load_data.py <data_dir> <out.npz>"""
import sys, os, zipfile, io
import numpy as np
import pandas as pd

data_dir, out = sys.argv[1], sys.argv[2]
frames = []
for fn in sorted(os.listdir(data_dir)):
    if not fn.endswith(".zip"):
        continue
    with zipfile.ZipFile(os.path.join(data_dir, fn)) as z:
        for name in z.namelist():
            raw = z.read(name).decode("ascii")
            first = raw.split("\n", 1)[0]
            has_header = not first[:1].isdigit()
            df = pd.read_csv(io.StringIO(raw), header=0 if has_header else None)
            df = df.iloc[:, :6]
            df.columns = ["t", "o", "h", "l", "c", "v"]
            frames.append(df)
df = pd.concat(frames, ignore_index=True)
df["t"] = df["t"].astype("int64")
if df["t"].max() > 10**14:          # microseconds -> ms
    df["t"] = df["t"] // 1000
df["t"] = df["t"] // 1000           # seconds, UTC open time
df = df.drop_duplicates("t").sort_values("t").reset_index(drop=True)
for col in "ohlcv":
    df[col] = df[col].astype("float64")
bad = (df.h < df[["o", "c"]].max(axis=1)) | (df.l > df[["o", "c"]].min(axis=1))
print("rows", len(df), "bad OHLC rows", int(bad.sum()))
print("from", pd.to_datetime(df.t.iloc[0], unit="s"), "to", pd.to_datetime(df.t.iloc[-1], unit="s"))
gaps = np.diff(df.t.values)
print("missing-minute gaps:", int((gaps > 60).sum()), "largest gap (min):", int(gaps.max() // 60))
np.savez_compressed(out, t=df.t.values, o=df.o.values, h=df.h.values, l=df.l.values, c=df.c.values, v=df.v.values)
# spot checks against the owner's broker screenshots (IC Markets, server = UTC+2)
for ts in ["2026-11-10 16:15", "2026-11-10 18:40", "2026-11-10 19:05"]:
    tt = int(pd.Timestamp(ts, tz="UTC").timestamp())
    row = df[df.t == tt]
    print("UTC", ts, "close", None if row.empty else float(row.c.iloc[0]))
