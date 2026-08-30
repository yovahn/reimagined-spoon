# Reimagined Spoon

Godot game project.

## Team setup

1. Install [Git for Windows](https://git-scm.com/download/win).
2. Download the **Standard** Windows edition of [Godot 4.7.2](https://godotengine.org/download/windows/). Use the Standard edition unless the project is intentionally changed to C#/.NET.
3. Clone the repository:

   ```powershell
   git clone https://github.com/yovahn/reimagined-spoon.git
   cd reimagined-spoon
   ```

4. In Godot's Project Manager, select **Import**, choose this repository folder, and open `project.godot`.

5. Press **F6** or the play button to run the forest adventure. Move with **WASD** and look with the mouse.

## Local two-player test

1. Run the project twice.
2. In the first window, use the upper-right panel to press **Host**. It listens on UDP port `7001`.
3. In the second window, keep the address as `127.0.0.1` and press **Join**.
4. Each window should show both the Host and Guest adventurers. Movement and crystal/shrine progress should appear in both windows.

For two computers on the same Wi-Fi network, host on one computer and enter the host computer's IPv4 address in the other player's address field. Remote play over the internet requires a later networking setup step such as UDP port forwarding or a virtual LAN.

## Current playable world

- A 3D forest adventure with base camp, meadow, river crossing, ancient clearing, landmarks, and world boundaries.
- A third-person adventurer with camera-relative movement, sprint, jump, and independent camera look.
- A shared two-player host/join panel in the upper-right. The host relays player movement and validates shared crystal collection and shrine restoration.
- A repeatable quest: collect three crystals with `E`, return them to the blue shrine, then press `R` to restart.

## Development notes

- Engine: Godot 4.7.2 (Standard)
- Script language: GDScript
- Keep the Godot-generated `.godot/` folder out of version control. It is recreated automatically.
- Before making changes, run `git pull`.
- After testing your work, use `git status`, `git add`, `git commit`, and `git push` to share it.

Important project files:

- `project.godot`: Godot project settings and startup scene.
- `scenes/world_3d.tscn`: The playable 3D world scene.
- `scenes/player_3d.tscn`: Reusable 3D player scene.
- `scripts/player_3d.gd`: Movement, camera, and player synchronization.
- `scripts/world_3d.gd`: World interactions and multiplayer state.
