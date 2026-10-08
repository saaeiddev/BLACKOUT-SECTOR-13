# BLACKOUT: SECTOR 13

Created by Amir Saeid Dehghan.

An original native, offline, single-player first-person industrial horror shooter. This source archive supplements the Windows installer and portable game; players do not need this source or any development tools.

## Player deliverables

- `BlackoutSector13-Setup-1.0.0.exe`: NSIS per-user installer, Start menu shortcuts, optional desktop shortcut, launch option and uninstall support.
- `BlackoutSector13-Windows-x64-Portable-1.0.0.zip`: extract the complete folder, then open `BlackoutSector13.exe`.
- The Persian player guide, QA report and third-party notices accompany the binaries.

## Campaign

Arrival and equipment; two auxiliary feeders in the west switchgear and east substation; generator restoration; security access; laboratory and shotgun; three containment waves; three reactor regulators and an elite encounter; evacuation and ending. Includes Normal/Easy, field records, facility map, settings, rebinding and checkpoint saves.

The requested 15–25 minute first-player duration is a design target, not a measured claim. Automated optimal-route tests are much faster. See the release QA report for exact coverage and limitations. Native Windows 11 installation/gameplay and RTX 4060 performance have not been verified in this environment.

## Pinned build stack

- Godot **4.5.1.stable.official.f62fdbde1**, GDScript, Compatibility renderer.
- Exactly matching **4.5.1.stable** official Windows x64 export templates.
- NSIS **3.09** (Linux compiler, Unicode installer).
- Python 3 with Pillow/NumPy only to regenerate the already-bundled original assets.
- LIEF `1.0.0-d05b3499b` and pefile were used for cross-platform Windows icon/version-resource updates. `build/set_windows_metadata.py` verifies that executable code, entry point and imports are unchanged.

Use official engine/template downloads and validate against the matching `SHA512-SUMS.txt`. Install templates in the Godot per-user `export_templates/4.5.1.stable` folder.

From the parent directory containing `game/`, create `artifacts/release`, `artifacts/linux-qa`, `tools` and `logs`. Run the Godot editor once headlessly with `--headless --path game --editor --import --quit`, then export the `Windows Desktop` preset with `--headless --path game --export-release "Windows Desktop"`. The Linux QA preset is for development validation only.

Compile `game/build/metadata.nsi` with NSIS, then run `python3 game/build/set_windows_metadata.py artifacts/release/BlackoutSector13.exe tools/game-metadata.exe`. Copy the guide, QA report and notices into `artifacts/release`. Compile `game/build/installer.nsi` with NSIS. ZIP the whole release directory under a single `BlackoutSector13` folder. No public publishing or CI account is required.

The release is unsigned. No signing credentials were used. Do not describe export or Linux testing as Windows 11 testing.

### Optional rebuilding on Ubuntu x64

For developers only; none of this is required to install or play. The bundled
`build/bootstrap_tools.py` retrieves the pinned official engine and templates,
checks their SHA-512 sums, and extracts Ubuntu Noble NSIS/Xvfb/7zip packages into
`tools/prefix`. It does not use an administrator package-manager installation.
It requires network access, Python 3, `dpkg-deb`, and sufficient free disk space
for the 1.36 GB template archive. Godot also needs the usual Linux graphics
libraries. The QA runner needs software OpenGL/Mesa. Run from the parent of
`game/`:

```sh
python3 game/build/bootstrap_tools.py
python3 -m pip install lief==1.0.0 pefile==2024.8.26
mkdir -p artifacts/release artifacts/linux-qa logs
tools/Godot_v4.5.1-stable_linux.x86_64 --headless --path game --editor --import --quit
tools/Godot_v4.5.1-stable_linux.x86_64 --headless --path game --export-release 'Windows Desktop'
tools/Godot_v4.5.1-stable_linux.x86_64 --headless --path game --export-release 'Linux QA'
NSISDIR="$PWD/tools/prefix/usr/share/nsis" tools/prefix/usr/bin/makensis game/build/metadata.nsi
python3 game/build/set_windows_metadata.py artifacts/release/BlackoutSector13.exe tools/game-metadata.exe
python3 game/build/qa_runner.py
cp game/docs/Player-Guide-FA.html game/docs/THIRD-PARTY-NOTICES.txt game/docs/QA-Report.md artifacts/release/
python3 game/build/package_release.py
```

Re-run and update the QA report for a changed build; the supplied report only
describes the delivered hashes. Package validation checks extraction and byte
equality; it does not claim Windows execution. Build outputs are not promised
to be byte-for-byte deterministic across different system/tool installations.

## Tests

Exported builds accept `-- --qa-smoke`, `-- --qa-reload`, `-- --qa-campaign`, and `-- --qa-campaign-easy`. These modes are development automation, not a substitute for visual Windows playtesting. Run them with an isolated per-user data directory; they overwrite that test profile's save. Set `BLACKOUT_QA_DIR` to an existing output directory for JSON results and genuine rendered screenshots. Campaign automation uses ordinary movement, collision, interaction rays, weapon damage, reloads and healing; it does not teleport through the campaign or grant ammunition/health.

Smoke tests use explicitly staged fixtures and scene views. Their screenshots are rendered by the actual game, not image-generation artwork. `qa-reload` should run in a new process with the profile produced by `qa-smoke`.

## Assets and licensing

All project-specific models, rig animations, textures, UI and sound design were authored procedurally for this project. The bundled audio is synthesis, not recorded voice acting. No external runtime asset downloads or web server are used. The complete Godot and NSIS notices ship in `THIRD-PARTY-NOTICES.txt`.

Original project-specific files may be used, modified and redistributed by Amir Saeid Dehghan. Third-party engine and installer components remain subject to their respective licenses.
