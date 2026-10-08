# BLACKOUT: SECTOR 13 — QA 1.0.0

Created by Amir Saeid Dehghan

## نتیجه و حدود اطمینان

خروجی واقعی Windows x64، نصاب NSIS و ZIP قابل‌حمل ساخته شده‌اند. آزمون‌های اجرا روی **لینوکس** انجام شده‌اند؛ نصب و اجرای واقعی روی **Windows 11 آزمایش نشده است**. این نسخه را کاملاً آزموده‌شده یا واجد تمام معیارهای پذیرش معرفی نمی‌کنیم.

۳۱ بررسی خودکار اجراشده بدون شکست پایان یافت: ۲۶ بررسی گرافیکی، ۳ بررسی ذخیره و بارگذاری در فرایند تازه، و تکمیل کمپین در هر دو درجهٔ سختی. بررسی تصاویر واقعی شامل منو، تنظیمات، ورودی امنیت، آزمایشگاه، راکتور و دفترچه است. این کار جای بازی کامل دستی را نمی‌گیرد.

## محیط و فایل دقیق آزمون

- Engine: Godot **4.5.1.stable.official.f62fdbde1**, GDScript, Compatibility renderer.
- Exactly matching official **4.5.1.stable** Windows x86_64 release templates; engine and template downloads checked against official SHA-512 sums.
- NSIS **3.09**, Unicode, per-user installer. NSIS itself is x86; the installed game is **PE32+ AMD64**.
- Host: **Ubuntu 24.04.3 LTS x64**, Xvfb at **1280×720**.
- Graphics: **OpenGL 4.5, Mesa 25.2.8, llvmpipe / LLVM 20.1.2** software rendering. No physical NVIDIA GPU was available.
- Audio: **Dummy** output driver. Audio resources loaded; no speaker/headphone listening test.
- The actual exported Linux executable was used, outside the editor, with the **byte-identical PCK from the Windows export**.
- Runtime and PCK were placed in `Portable QA با فاصله`; launch working directory was `/tmp`.
- Isolated per-test user profiles were used. Player saves are not bundled.
- Windows EXE metadata rebuilt using LIEF 1.0.0 and pefile 2024.8.26; code-section hash, imports and entry point verified unchanged.

## ماتریس آزمون

| بررسی | نتیجه | شواهد و محدوده |
|---|---|---|
| Windows x64 export / exact template version | PASS | Successful export; AMD64 PE header and local companion PCK checked |
| Windows icon, version and creator metadata | PASS | PE resources inspected; version 1.0.0; original filename and creator set |
| Actual NSIS installer compilation | PASS | Compilation succeeds without warnings; version/icon, per-user location, optional desktop shortcut, Start shortcuts and uninstall code included |
| Installer payload extraction and portable ZIP integrity | PASS | All five release files extracted and byte-compared; ZIP CRC and required filenames checked; see Package-Verification.json |
| Clean Windows 11 install / first launch / shortcuts | NOT TESTED | No Windows 11 environment available |
| Windows quit / relaunch / uninstall / reinstall | NOT TESTED | Static uninstall review preserves saves and deletes named application files only; native lifecycle unverified |
| Windows portable double-click launch | NOT TESTED | Real Windows executable delivered; native execution unverified |
| Exported Linux graphical launch | PASS | 26 smoke checks, zero failures; actual runtime, no editor session |
| Spaces / Persian characters / unrelated working directory | PASS | Tested on Linux path above; non-ASCII Windows username/path NOT TESTED |
| Main menu, settings, credits, overwrite confirmation, pause, death/restart | PASS | Automated menu/state checks; real screenshots; all physical button-click paths and every setting combination NOT TESTED |
| Movement, grounded collision, crouch/stand clearance | PASS | Input-driven movement and collider checks; broad stair/slope/geometry stress pass NOT TESTED |
| Pistol, shotgun, reload conservation/cancel, pickups, medkit | PASS | Damage rays, shell consumption, reload duplicate rejection, equipment interaction and healing checks |
| Solid wall prevents weapon damage | PASS | Enemy behind solid wall retained health |
| Enemy wind-up / damage timing | PASS | No damage during initial wind-up, then damage after strike; campaign navigation exercised |
| Pause releases cursor / resume captures cursor | PASS | Actual graphical mouse-mode checks |
| Focus-loss safety handler | PASS | Focus-out notification injected; physical Windows Alt-Tab NOT TESTED |
| Settings save and key rebinding | PASS | Sensitivity persistence and reload-key rebinding checked |
| Missing/corrupted save handling | PASS | New profile has disabled Continue; corrupt JSON rejected without crash |
| Save/load across separate exported processes | PASS | 3 checks: valid save, restored mission/equipment/defeated actors, restored closed lab gate |
| Whole campaign — Normal | PASS | Simulation seconds: 388.1; killed=48; all objectives reached ending |
| Whole campaign — Easy | PASS | Simulation seconds: 388.5; killed=48; all objectives reached ending |
| Full manual graphical campaign playthrough | NOT TESTED | Campaign completion was automated/headless; screenshot fixtures are separate |
| Local assets / standalone dependency inspection | PASS | Assets packed locally; imported DLLs are Windows system components; no editor/Python/Node needed by player |
| Disconnected-network Windows installation/play | NOT TESTED | No game network/download code or remote assets; actual Windows offline execution unverified |
| Final Linux missing-resource/script/crash/exit-leak log checks | PASS | None found in final four QA logs |
| Audible audio / spatial balance / Windows devices | NOT TESTED | Dummy output used; no voice acting claimed |
| RTX 4060 laptop, 1080p / stable 60 FPS | NOT TESTED | Hardware unavailable; this remains a target, not a benchmark |
| All resolution, fullscreen, VSync and graphics combinations | NOT TESTED | Options implemented; virtual graphics driver rejects changing VSync |
| First-time human campaign duration of 15–25 minutes | NOT TESTED | Optimal bot completes in about 6.5 simulated minutes; actual first-player pacing not established |

PASS means only the stated scope passed. NOT TESTED is not evidence of either success or failure. No executed final automated check reported FAIL.

## روش، تصاویر و محدودیت‌ها

- `qa-smoke` uses scripted fixtures, direct control calls and synthetic input. Its screenshots are genuine frames from the exported game. Laboratory/reactor views deliberately set a scene position and mission stage; they do not document a continuous human playthrough.
- The separate campaign bot starts from a new game, moves using ordinary controls/collisions, collects through interaction rays, shoots, reloads and heals. It does not teleport through mission objectives or grant health/ammunition.
- The game is an original, modest low-poly independent production, not photorealistic or AAA. Weapons, animated creatures, environment, textures and synthesized sounds are procedural project assets. Narrative is subtitled radio text; there is no recorded voice acting.
- Files are **unsigned**. No certificate or public publishing was used. No advice to disable Windows security is required.
- The Xvfb run logs one expected unsupported-VSync warning. Xvfb also logs harmless missing multimedia key-symbol and interface-enumeration warnings; these are retained in evidence. They are not silently represented as a Windows driver result.
- Previously observed Wine limitations do not count as Windows testing. No Windows CI run was performed.
- Save/settings location on Windows is `%APPDATA%\BlackoutSector13`. Uninstall code preserves it. This native uninstall behavior still needs Windows verification.
- No physical GPU performance measurements or audio listening results are claimed.

## اثرانگشت محتوای بازی

| File | Bytes | SHA-256 |
|---|---:|---|
| BlackoutSector13.exe | 96725504 | `8b5a9b7a8ef1bad226927c1e7a464776865f4ca259157d3ebea77e5d178a5266` |
| BlackoutSector13.pck | 1170496 | `b2e887e2503e2f298b3dab7590877c522353eff81546aac20b4d782d7a51ae6b` |

Final installer, portable ZIP, source and evidence sizes/checksums are supplied in `SHA256SUMS.txt` and `Release-Manifest.json`. These are outside the archives to avoid self-referential checksums. The evidence ZIP contains raw logs, JSON check results, package verification and six unedited screenshots.
