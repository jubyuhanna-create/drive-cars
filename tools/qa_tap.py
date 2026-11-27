#!/usr/bin/env python3
"""Print the center "x y" of the first UI node whose text or content-desc matches. usage: qa_tap.py ui.xml LABEL [LABEL...]"""
import re, sys, xml.etree.ElementTree as ET
try:
    root = ET.parse(sys.argv[1]).getroot()
except Exception:
    sys.exit(1)
labels = sys.argv[2:]
for exact in (True, False):
    for lab in labels:
        for n in root.iter("node"):
            t = (n.get("text") or "") + "|" + (n.get("content-desc") or "")
            parts = t.split("|")
            ok = lab in parts if exact else any(lab in p for p in parts)
            if ok:
                m = re.findall(r"\d+", n.get("bounds", ""))
                if len(m) == 4:
                    x1, y1, x2, y2 = map(int, m)
                    print((x1 + x2) // 2, (y1 + y2) // 2)
                    sys.exit(0)
sys.exit(1)
