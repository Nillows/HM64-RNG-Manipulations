# SaveRAM: the game files behind each set of tables

One folder per game-file circumstance, named like the site's pages. Every file is a BizHawk `.SaveRAM` (diary slot 1),
read field by field with the lab's `tools/save_check.py` (offsets from the decomp's `sramBuffer.h`); all checksums valid.
In every file: year 1, spring, rod in Jack's hand, the dog left on the beach on the lineup2 tile (view tile 18:23, the
far south-west corner), 300 G, full stamina.

| folder | file | sha256 | day | weather (forecast) | horse | family | dog x / z | used for |
|---|---|---|---|---|---|---|---|---|
| `sunny-no-horse` | `…beach-lineup2.SaveRAM` | 52cfd712… | spring 4 | sunny (rain) | no | single | −198.515 / 223.485 | Sunny · No horse pages |
| `sunny-horse` | `…beach-lineup2-horse.SaveRAM` | b0f2a284… | (see the lab notes) | sunny | yes | single | −196.908 / 222.092 | Sunny · Horse pages |
| `rainy-no-horse` | `…beach-lineup2-nohorse-rainy.SaveRAM` | 8e972d75… | spring 5 | rain (sunny) | no | single | −198.515 / 223.485 | Rainy · No horse pages |
| `rainy-horse` | `…beach-lineup2-horse-rainy.SaveRAM` | 287c11a6… | spring 9 | rain (sunny) | yes | single | −196.908 / 222.092 | Rainy · Horse pages |
| `married-sunny-no-horse` | `…married-sunny-spring9.SaveRAM` | 237e3d1d… | spring 9 | sunny (rain) | no | married (Karen), no baby | −197.272 / 222.243 | married run (2026-11-25), pages not built yet |
| `married-sunny-no-horse` | `…married-sunny-spring8-festival.SaveRAM` | 01999fee… | spring 8 | sunny (rain) | no | married (Karen), no baby | −197.272 / 222.243 | the original of the file above; spring 8 is the Planting Festival, which is NOT in any table |
| `married-rainy-no-horse` | `…married-rainy.SaveRAM` | 62991249… | spring 9 | rain (sunny) | no | married (Karen), no baby | −197.272 / 222.243 | married run (2026-11-25), pages not built yet |

Notes
- The tables are for ordinary mornings only: no festival, no morning cutscene.
- `…married-sunny-spring9` is the spring-8 file with only the date changed (day 9, Tuesday) and the checksum fixed
  (`tools/save_redate.py`); nothing else differs.
- The three dog spots are all on tile 18:23 but not the same point (0.4 to 1.8 units apart).
- The married files were made by editing a save, not by playing to the wedding.
