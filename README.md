# ☁️ Candy Cloud Climb

An original, kid-friendly Roblox obby. You climb a rainbow course floating in the sky, collect stars, dodge pink goo, and finish at a golden trophy.

**The whole level is built by one script.** You don't have to place any parts by hand. Paste the script in, press Play, and the course appears.

## What's in the game

| Stage | Obstacle | What you do |
|---|---|---|
| 1 | Rainbow stepping stones | Hop across zig-zag stones |
| 2 | Spinner bridge | Jump over 2 spinning pink goo bars |
| 3 | Vanishing tiles | Keep moving, because tiles fade after you step on them |
| 4 | Bounce pads | Green pads launch you up. Steer forward in the air! |
| 5 | Tightrope | Walk along thin candy-stripe beams |
| 6 | Cloud spiral | Climb cloud steps around a giant candy pole |
| 7 | Tricky stones | Smaller stones, bigger gaps |
| 8 | Super spinner bridge | 3 faster goo bars |
| 🏆 | Golden trophy | Confetti, +1 Win, and a **rainbow trail** that sticks with you |

- White glowing platforms are **checkpoints**. Fall off and you pop back to the last one.
- The scoreboard (top right) shows **Stage**, **Stars** and **Wins**.
- **Running:** hold Shift on a computer, tap the **Run** button on a phone or tablet, or click the left stick on a controller.
- **Cheat panel:** tap the little ✨ button on the left side of the screen (or press **H**) and pick a checkpoint number to warp there. 🏆 warps to the trophy. No chat needed. If chat is on, typing `/hh 5` in chat also works.
- A green **Play again** pad in the corner of the trophy platform sends you back to the start.

## Setup in Roblox Studio (about 5 minutes)

1. Install **Roblox Studio** from https://create.roblox.com and sign in.
2. Click **New**, then pick the **Baseplate** template. (The script removes the baseplate and builds its own world.)
3. On the right, find the **Explorer** panel. If you can't see it, go to the **View** tab and click **Explorer**.
4. Hover over **ServerScriptService**, click the **➕** button, and choose **Script**.
5. Delete the `print("Hello world!")` line that's already in it.
6. Open [`src/server/CandyCloudClimb.server.luau`](src/server/CandyCloudClimb.server.luau), copy **everything**, and paste it into the script.
7. Optional: right-click the script, choose **Rename**, and call it `CandyCloudClimb`.
8. **Add the two player scripts:** in Explorer, open **StarterPlayer**, hover over **StarterPlayerScripts**, click **➕** and choose **LocalScript** (not Script!). Delete its `print` line and paste in everything from [`src/client/WorldMotion.client.luau`](src/client/WorldMotion.client.luau) (this spins the goo bars and bobs the stars). Do it once more with [`src/client/Sprint.client.luau`](src/client/Sprint.client.luau) (this adds running).
9. Press **Play** (or F5). After a second you'll spawn on the start platform with the course in front of you.
10. Press **Stop** (Shift+F5) to go back to editing.

**Controls:** WASD or arrow keys to move, **hold Shift to run**, Space to jump, right mouse button to turn the camera, mouse wheel to zoom.

### Play it with friends or on other devices

1. **File → Publish to Roblox**, give it a name and description, and click **Create**.
2. Open **Game Settings → Permissions** and set it to **Public** if friends should be able to join (or leave it Private so only your account can play).
3. It now shows up under **Creations** on roblox.com, and you can play it on a phone, tablet, Xbox, or PC.

## Make it your own (great for your daughter to try!)

Everything fun is at the top of the script:

- **`CONFIG`**: game name, how high the course is, bounce strength, spinner speed, how long tiles stay gone.
- **`RAINBOW`**: the six platform colors. Change any `Color3.fromRGB(red, green, blue)` (each number is 0 to 255).
- **`GOO_COLOR`, `GOLD`, `STAR_COLOR`, ...**: other colors.
- **The course list** (search for `local course = {`): reorder obstacles, remove one, or add more. For example, copy `steppingStones(e, 6, 6, 4)` and change the numbers (count, stone size, gap).

Easy first edits to try:
- Make the bounce pads super bouncy: `BouncePower = 140`
- Make spinners slower: `SpinnerSpeedEasy = 0.8`
- Run even faster: in `Sprint.client.luau`, change `RUN_SPEED = 32` to `40`
- Rename the game: `GameName = "Lily's Sky Party"`

## Developer setup with pixi (optional, for code editors)

The tooling is managed with [pixi](https://pixi.sh). Install pixi once, then everything else comes from this repo.

```sh
pixi run serve   # live-sync into Studio with Rojo
pixi run build   # make CandyCloudClimb.rbxlx you can open in Studio
pixi run fmt     # format the code with StyLua
pixi run lint    # lint with Selene
pixi run check   # format check + lint
```

Rojo isn't on conda-forge, so the first `serve` or `build` compiles it with cargo into `.pixi/rojo` (a few minutes, only once).

To live-sync: install the Rojo plugin in Studio (Plugins → Manage Plugins, or from https://rojo.space), run `pixi run serve`, then click **Connect** in the Rojo plugin. Saving the `.luau` file updates the game in Studio right away.

```
candycloud/
├── pixi.toml                 tools and tasks
├── default.project.json      Rojo project (maps src/server → ServerScriptService)
├── stylua.toml / selene.toml formatter and linter settings
├── src/server/
│   └── CandyCloudClimb.server.luau   the whole level and game rules
└── src/client/
    ├── WorldMotion.client.luau       spins goo bars, bobs stars (on each screen, no lag)
    └── Sprint.client.luau            running (Shift / Run button)
```

## Notes

- Progress (stars and wins) resets when you leave. Saving progress needs DataStores, which only work after you publish the game and turn on **Game Settings → Security → Enable Studio Access to API Services**.
- No sounds or images from the Roblox library are used, so nothing can break if an asset is removed.
