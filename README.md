# drive-cars

<!-- codes -->
## أكواد السيارات

اكتب الكود بشاشة Drive وبتنزل السيارة باللون.

| السيارة | أبيض | أسود | رمادي جرافيت | فضي | أحمر | أزرق |
|---|---|---|---|---|---|---|
| Skoda Superb 2020 | `Y96YN` | … | `YLBLW` | … | … | … |
| Skoda Octavia 2019 | … | … | … | … | … | … |
| Toyota Corolla 2014 | … | … | … | … | … | … |
| Volkswagen Golf Gti MK7 | … | … | … | … | … | … |
| Volkswagen Golf 7 2014 | … | … | … | … | … | … |
| Seat Ibiza 2022 | … | … | … | … | … | … |
| Seat Leon Cupra R 2018 | … | … | … | … | … | … |
<!-- /codes -->

Public files for the **Drive** car launcher. The app only reads from here, it never writes and holds no token.

| Path | What it is |
|---|---|
| `c/<CODE>.carpack` | One customer's car. The screen downloads it when the code is typed in. |
| `app.json` + `app/drive-<version>.apk` | Newest Drive version. The app checks this to update itself. |
| `catalog.json` | Optional list of public cars. |
| `tools/make_pack.py` | Builds a `.carpack` from rendered pictures. |

## carpack-2

A ZIP file:

```
meta.json                 {"format":"carpack-2","id","brand","model","year","color":{k,n,hex},"spin":{n,rows,w,h,start:[row,index]}}
<color>_off.webp          home picture, lights off
<color>_on.webp           home picture, lights on
spin/<row>_<index>.webp   360 frames, transparent background
```
