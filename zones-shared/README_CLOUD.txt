HM64 lab: several Macs on one table (2026-11-25) - the rainy camera-zone campaign, shared
==========================================================================================
What it is
  The zone campaign of hm64-powernut-lab_zones_2026-11-25.zip, unchanged in what it measures, with one addition: the
  job list is cut into 50 blocks and every Mac is started with a direction:
      bash run_hm64_zones_shared.sh up        from the top of the list down
      bash run_hm64_zones_shared.sh down      from the bottom up
      bash run_hm64_zones_shared.sh middle    from the middle out, alternating sides (a third Mac)
  A Mac claims a block, runs it, marks it done. The claims travel through the branch lab-coord on GitHub
  (tools/hm64_coord_sync.sh, every 30 s; each Mac writes only its own file). A Mac stops when every block is done by
  somebody. A Mac silent for 90 minutes loses its claims to the others. A block done twice is harmless.
  Each Mac uploads its part to lab-data: hm64-zones-<label>@<machine>.zip. Claude merges the parts and makes the report.

Another Mac (once): on the Mac that has the lab
      bash hm64_cloud_setup.sh user@other-mac
  copies over the LAN (never GitHub): lab code, ROM, saves, the rainy dog-watch results and beach savestates, the
  pier-spot gate files, the Docker image hm64-lab:arm64 and this package; checks everything by sha256; prints the
  start command. The other Mac needs: Docker Desktop opened once on its own screen, Remote Login on, and its GitHub
  key (~/.ssh/hm64_github_ed25519, from the key block).

The Mac that is already running the zone campaign
  Stop it (Ctrl-C in its terminal) and start   bash run_hm64_zones_shared.sh up   from this folder: everything it has
  already measured counts, and it then shares the table. Left running as it is, it simply does the whole list itself
  (the other Mac's work is then done twice: harmless, but no time is saved).

Tested (sandbox, x86 emulator, Docker stand-in): machine B bottom-up, killed inside a block; machine A top-down to
the end incl. taking over B's open block: all 28 jobs covered, every row identical to the single-machine run. The
claim logic with 2 and 3 simulated machines over a real git remote: no job missed, none run twice.
NOT tested: on a Mac (bash 3.2 / Docker Desktop), the setup script over a real ssh connection, a real GitHub push.
