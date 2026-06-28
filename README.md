# BATOCERA ENHANCED ARM64 BUILDS  
**Unofficial Community Builds**

**Download:**  
https://drive.proton.me/urls/RRPFQ38NX8#LmFz5AIaV2aI

---

## Current Builds
- Odin 3 (Beta)
  <img width="1175" height="881" alt="image" src="https://github.com/user-attachments/assets/57433181-374b-4015-980f-18938350a717" />
  <img width="715" height="953" alt="o3-steam" src="https://github.com/user-attachments/assets/e16680ca-393e-4c8e-b0d5-a9308c00a8a3" />

- Odin2 / Thor Series  
- Powkiddy X55
- Anbernic RG-DS (Beta)
<img width="559" height="746" alt="image" src="https://github.com/user-attachments/assets/2f539866-4174-4c5c-b03c-2676ad81bd74" />
<img width="481" height="642" alt="image" src="https://github.com/user-attachments/assets/2ac8e6a1-769b-4ddb-b0ea-f04324146561" />


- Dragon Q6A  
- R36s  
- BattleXP G350  

---

## Core Features (All ARM64 Builds)
- Flatpak enabled (with DBus + Wayland fixes)  
- Wine + Box64 + Box86  
- PortMaster fixes with multilib 32-bit support  (32bit not availble on CQ8725S)



- MAME 0.139 (2010)

### Additional CLI Tools Included
- nodejs / npm
- pax-utils  
- file, lddtree, neofetch  
- tree, strace, strings, xmlstarlet, and more

Extra libraries (e.g. `libcups`) included for better AppImage compatibility  




---

## Qualcomm Builds (SM8550, CQ8725S, QCS6490)
Includes additional emulators where supported:
- AetherSX2  
- ARMSX2 (+Masies fork with newer aarch64 JIT engine)
- RPCS3
- Vita3K
- Cemu (now upstream)
- Xenia
  <img width="661" height="881" alt="image" src="https://github.com/user-attachments/assets/ce658ce6-7753-47fd-a56e-caaeddf29c67" />
- SkyEmu  
- NanoBoy Advance
- Gopher 64
- Yaba Sanshiro Standlone
- And more emulators
- Dusk Port Engine
- Opeangoal Engine
- Steam aarch64 (aarch64 client) (with drm/kms gamescope working on sm8550/sm8750)
- DXVK (DX11 support)
- Fex-Emu support on Wine runners
- LSFG-VK (requires Losless.dll - can be bought on steam)
  <img width="661" height="881" alt="image" src="https://github.com/user-attachments/assets/7183369d-ca34-4d24-9f6b-86d35feb9918" />
- Docker *(enable in Services menu)*
- Waydroid
- Hotkey + touchscreen support for on-screen keyboard  

---

## SM8550 (Snapdragon 8 Gen 2 Class)
- Odin 2 includes LED support
- GPU Profile settings
- experimental gamescope for wine, cemu
- Strong DX9 / DX10 support  
- Many DX11-era titles may run  
- Vulkan-native titles perform best  
- Not a replacement for x86 gaming PCs

## Extra thor perks like lower widget Conky System monitor, retroarch lower panel controls, waydroid
  <img width="661" height="881" alt="image" src="https://github.com/user-attachments/assets/2696ed6f-0bdd-48f6-9c82-d4e3ed377acb" />
  <img width="583" height="777" alt="image" src="https://github.com/user-attachments/assets/8f00df20-a3e4-40a8-a8aa-eda8cbea1ae7" />
  <img width="661" height="881" alt="image" src="https://github.com/user-attachments/assets/307330f2-39b4-4c33-8893-85c19507884f" />


## CQ8725S (Dragonwing Q8 - Odin 3)
- Same stack as above with more power
- Waydroid currently not working on CQ8725S as Adreno 830 currently doesn't support hardware acceleration on waydroid.
  

---

## Qualcomm GPU Stack
- Mesa + Freedreno + Turnip drivers  


### General Notes
- Performance varies heavily by engine  
- DXVK improves compatibility but is not magic  
- CPU-heavy or shader-heavy games may still struggle  
- aarch64 Wine translation overhead remains a factor  

---

## Rockchip / Allwinner Devices


  
### Wine Expectations
> “No! It can't run Crysis”

### Wine Performance Guidelines (Rockchip)
These SoCs are limited by:
- Cortex-A35 / A53 / A55 class CPUs  
- Panfrost driver maturity  
- Memory bandwidth  

#### RK3326 / H700
- Target: early DX8 / DX9 era  
- Pre-2005 recommended  
- 2D engines perform best  

#### RK3566/8
- Light DX9 titles possible  
- Shader-heavy games will struggle
- Vulkan enabled in libmali mode -- helps especially with PPSSPP, Azahar, Flycast (Thanks Sydarn)
- Azahar enabled - don't expect fullspeed, usually
- Dolphin working with light gamecube titles on RG-DS

Do **NOT** expect:
- DX10 / DX11 performance  
- Modern Unity / Unreal engines  
- Heavy physics or CPU-bound games  

### GPU Stack
- Mesa + Panfrost  
- Powkiddy X55 & RG-DS have mali blobs with gpudriver toggle in settings to panfrost
---

## Support Policy
**DO NOT** ask for support on the official Batocera Discord or Reddit.  
These are unofficial builds and are **NOT supported** by the Batocera team.  

---

## Upstream Contributions

This project focuses on building a modern, feature-rich Batocera variant. The goal is to deliver working integrations quickly, not to manage upstream contribution workflows.

All source code is provided in full compliance with open-source licensing.
If you would like a feature from this project included upstream:

- You are free to submit a PR upstream yourself
- You may reuse or adapt any code from this repository (per license terms)
- You are responsible for meeting upstream requirements, scope, and policies

Please do not request that features from this project be upstreamed on your behalf.

This project intentionally targets a different scope (modern hardware, newer graphics stack, etc.), and not all features are designed to align with upstream constraints.

---
## License & Disclaimer
- Released under Batocera’s LGPLv3 & Buildroot's GPLv2 License  
- Source code is included  
- Use at your own risk  
- No warranty  
- No support provided
 --- 
 
## Credits

Thanks to:

- The Batocera Team for core development
- Rion for initial draft of gamescope 
- UUreel
- Cliffy
- Contributors from batocera.pro whose work was integrated

---

x86-64 PC builds are here: https://github.com/suckbluefrog/Batocera-Multilib
