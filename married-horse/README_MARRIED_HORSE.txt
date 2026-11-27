HM64 lab pool campaign "married-horse" (2026-11-27a) - dog lines and all casts to 120 s for the married + horse saves

  main Mac:  bash ~/Documents/hm64/hm64-pool/hm64_pool.sh run married-horse topdown </dev/null

Saves (Thomas, married-hashorse.zip, 2026-11-27 00:10; found by sha256 in sourcefiles / Downloads / a *married*.zip):
  sunny  0f33f322...  spring 13, sunny, married to Karen, no baby, pony on the farm at x 492.879 z -69.384
  rainy  8cbe43a5...  spring 12, rain,  the same
  dog on the beach at x -197.272 z 222.243 (tile 18:23) on both, rod in hand.
Sandbox (x86 bundle, 2026-11-27, two cold boots each): the reference route gives house 1036/499, farm 1448/704,
beach 2264/1083, READY draw 1269 on the sunny save = the unmarried sunny horse save's record (so the pony stays off
the farm's visibility grid on that route, and the marriage adds no draw); rainy: beach 7429, READY 10593 = the rainy
horse save and the rainy no-horse saves.
Runner = run_hm64_married_shared.sh (2026-11-26d) with these saves; labels married-horse-lineup2-<save>-<sha8>, cast
folders results/fullday/marhorse-<save>-<window>. ARM image only: Macs. A helper Mac can join the cast blocks with
bottomup once it has the main Mac's finished dog-watch folders of these labels.
Zips: hm64-dogwatch-<label>.zip, hm64-fullday-marhorse-<save>-<window>@<machine>.zip; lab-data folders
married-horse-sunny / married-horse-rainy.
After this run: the pier-zone plan is made from these recordings (Claude), then a zones campaign like zones-married.
NOT tested: this runner end to end (only its checks: bash -n, save_check on both saves, the reference-route check).
