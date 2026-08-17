Pokemon Recomp — put your own canonical US dumps here.

This folder is the game list. Batocera hides empty systems, so the
system only appears after you add at least one .gb / .gbc file.

Accepted (SHA-1, US only, not zip):
  Red     ea9bcae617fdf159b045185467ae58b2e4a48b9a
  Blue    d7037c83e1ae5b39bde3c30787637ba1d4c48ce2
  Yellow  cc7d03262ebfaf2f06772c1a480c7d9d5f4a38e1
  Gold    d8b8a3600a465308c9953dfa04f0081c05bdcb94
  Silver  49b163f7e57702bc939d642a18f591de55d92dae
  Crystal f2f52230b536214ef7c9924f483392993e226cfb  (Rev 1)
          f4cd194bdee0d04ca4eac29e09b8e4e9d818c133  (Rev 0)

Samba: \\BATOCERA\share\roms\pkmnrecomp\
SSH:   /userdata/roms/pkmnrecomp/

In-game (Odin / SDL pad):
  D-pad or left stick  Move
  L2                   Toggle pixel-perfect GB aspect (10:9 letterbox)
  R2                   Toggle 2X speed
  L1 / R1              Cycle speed up/down (vanilla)
  OPTIONS → CONTROLS   Rebind A/B/Start/Select

Tools (EmulationStation → Tools):
  Configure Gen1Recomp / Configure Gen2Recomp
  open the vanilla launcher to change options, controls and mods.

Mods (ZIP or folder under the drop dirs; auto-unpacked on launch):
  mods/gen1/      -> gen1recomp  (e.g. potato_voxel = 3D voxel overworld)
  mods/gen2/      -> gen2recomp  (e.g. DRAMATIC_SHAPE = 3D diorama)
  mods/optional/  not auto-loaded (Nuzlocke); copy into gen1/ or gen2/ to use

Loader only sees folders mods/<id>/ with manifest.json. The launcher unpacks
ZIPs there, enables the 3D graphics mod, and seeds pipelines.voxel = FULL
(the diorama preset). Hotkey 3 / SELECT still cycles the camera ladder;
bundled Nuzlocke stays off.

