# Topspin

An original third-person 3D platformer for iPhone, iPad and Mac, written in Swift with a
hand-rolled Metal render pipeline. No game engine, no external assets — every mesh is
generated procedurally at launch.

> **This is an original work.** The character, art, level, names and code are all created
> from scratch for this project. It is *not* a port, clone, or reproduction of any
> commercial game, and it contains no third-party game content of any kind.

---

## What it is

You play **Pip**, a small service robot whose cap can be thrown at the local wildlife.
Hit a creature and Pip takes it over, inheriting its movement profile. That single
mechanic is the whole design: the same level plays differently depending on which body
you are wearing.

| Host | Speed | Jump | Feel |
| --- | --- | --- | --- |
| Pip (default) | 6.2 | 9.8 | Balanced |
| Walker (red block) | 4.2 | 11.8 | Slow, but leaps tall ledges |
| Hopper (purple sphere) | 8.8 | 8.4 | Fast, but barely clears a step |

Collect all 10 coins and reach the beacon on the far platform to clear the course.

## Controls

| Input | Action |
| --- | --- |
| Touch the left half of the screen | Floating virtual stick appears under your finger |
| Drag anywhere else | Orbit the camera |
| **A** (right) | Jump — hold for full height, release early to cut it short |
| **B** (right) | Throw the cap; press again while possessing to release the host |

---

## Getting an installable IPA

An `.ipa` is not something you can produce from source on any machine — it is the output of
**Xcode compiling the app for `arm64` and then code-signing it**. That step requires macOS.
There are three ways to get one; pick whichever fits what you have.

> Whichever route you take, the IPA still has to be signed with an Apple ID before iOS will
> install it. See [Signing and installing](#signing-and-installing) below.

### Route A — You have a Mac

```sh
cd Topspin
chmod +x build_ipa.sh
./build_ipa.sh
```

That generates the project, builds Release for `iphoneos`, and writes
`Topspin-unsigned.ipa` next to the script. If you'd rather use the Xcode GUI:

```sh
brew install xcodegen
xcodegen generate
open Topspin.xcodeproj
```

Then *Product → Archive*, and in the Organizer choose *Distribute App → Custom → Release
Testing* (or *Ad Hoc*) to export the IPA.

### Route B — You don't have a Mac: build it in the cloud for free

The repo ships a GitHub Actions workflow at `.github/workflows/build-ipa.yml` that builds the
IPA on a **macOS runner**. No Apple Developer account needed — the build is unsigned.

**1.** Create an empty repository on GitHub (no README, no .gitignore — it must start empty).

**2.** From inside this folder, push it. Note that the *contents* of `Topspin/` must become
the repository root, so that `.github/workflows/` sits at the top level where GitHub looks
for it:

```sh
cd Topspin
git init
git add .
git commit -m "Topspin"
git branch -M main
git remote add origin https://github.com/<your-username>/topspin.git
git push -u origin main
```

**3.** The workflow runs on push. Watch it under the *Actions* tab, or trigger it manually
there via *Run workflow*.

**4.** When the run goes green, open it and download the **`Topspin-unsigned-ipa`** artifact.
It arrives as a zip — unzip it to get `Topspin-unsigned.ipa`.

**5.** Hand that IPA to your sideloading tool. It will sign it with your Apple ID and install
it.

The workflow targets `macos-26` (arm64, Xcode 26.x) and picks whichever Xcode is newest on
the image. If you want the very newest toolchain, change `runs-on` to `xcode-27` — that image
carries Xcode 27 but is still a public preview with no SLA, so `macos-26` is the safer default.

macOS runners are **free and unlimited on public repositories**. On a private repo they draw
on your monthly Actions minutes, and a build here takes three to five minutes.

### Route C — Rent a cloud Mac

If you'd rather not use GitHub, hourly macOS instances work with Route A's instructions
unchanged. MacinCloud and MacStadium are the usual names; expect roughly a dollar or two
per hour, and you can finish in well under one.

### Without XcodeGen

Create a new iOS App project in Xcode, delete the generated `AppDelegate`/`ViewController`
files, drag the `Sources` folder in as a group, point *Info.plist File* at
`Resources/Info.plist`, and set *Generate Info.plist File* to **No**.

---

## Signing and installing

An unsigned IPA will not install on a stock iPhone. You need to sign it with an Apple ID
first. Two tiers:

| | Cost | App expires after | How |
| --- | --- | --- | --- |
| Free Apple ID | $0 | **7 days**, then re-sign | Sideloadly, AltStore, SideStore |
| Paid Developer Program | $99/year | 1 year | Ad Hoc export, or internal TestFlight |

**Sideloadly** is the least fuss for a Windows or Mac computer: download it from
[sideloadly.io](https://sideloadly.io), connect the iPhone by cable, drag
`Topspin-unsigned.ipa` in, type your Apple ID, and press Start. It signs the app on the fly
and installs it. On first launch, trust the developer certificate under
*Settings → General → VPN & Device Management*.

**AltStore / SideStore** are the better choice if you want it to re-sign automatically
before the 7-day window lapses, since they run on the device itself.

### Enable Developer Mode first

iOS 16 and later refuse to launch sideloaded apps until Developer Mode is on. On the
device: **Settings → Privacy & Security → Developer Mode**, switch it on, and reboot when
asked. If the toggle isn't there, connect the device to a computer running Sideloadly (or
to a Mac running Xcode) once — that is what makes the option appear.

### Free Apple ID limits

Worth knowing before you start, because they are enforced by Apple and cannot be worked
around:

- The app **stops launching after 7 days** until you re-sign it
- A free account can keep only **3 sideloaded apps** installed at once
- Apple allows **10 new App IDs per week** per account
- In-app purchases and Game Center never work on sideloaded builds

### A note on iOS 27 specifically

iOS 27 shipped on 14 September 2026, so it is only about a month old. Historically the
first months of a new major iOS release are rough for free-account sideloading — the
signing and device-pairing machinery that AltStore and SideStore depend on tends to break
on new OS versions and get patched back over time. SideStore has already had reported
pairing-file failures on recent releases.

Which tool you have matters, because they do not all still work on iOS 27:

| Tool type | Works on iOS 27? | Notes |
| --- | --- | --- |
| Sideloadly over USB | Usually | Most robust free path; pairing happens on a computer |
| AltStore / SideStore | Often broken right after a new iOS | On-device pairing is the fragile part |
| ESign / Scarlet / similar, using a shared or enterprise certificate | Depends on the certificate | The certificate, not the app, gets revoked — expect random breakage |
| TrollStore-style permanent install | **No** | That relied on a CoreTrust bug patched years ago; there is no signing-free permanent install on iOS 27 |

So if a free-account install fails on iOS 27, **that is most likely the tooling, not this
app**. Your options, roughly in order of reliability:

1. **Sideloadly over USB** — the most robust free path, since the pairing happens on a real
   computer rather than on-device. Try this first.
2. **Wait for a tool update**, or watch the AltStore/SideStore issue trackers.
3. **Pay for a developer account and use Ad Hoc or internal TestFlight.** Both use Apple's
   own distribution machinery rather than the free-account loophole, so they are not
   affected by the breakage above. Internal TestFlight testing (up to 100 people you invite)
   needs no App Review, and builds last 90 days.
4. **Borrow any Mac for an hour and run it in the iOS Simulator.** No signing at all is
   involved, and it is the fastest way to confirm the game works before fighting with
   certificates.

### Device requirements

- **iOS 15.0 or newer** — verified compatible with iOS 27, which is what the app targets
  going forward; the code uses no iOS 16/17-only APIs
- **arm64 + Metal** — in practice that means **iPhone 6s or newer**; every device that can
  run iOS 15 has both
- Landscape orientation only

### Performance

The scene is deliberately light: a few dozen indexed draw calls, one 176-byte uniform block
each, no textures, no shadow pass, 4× MSAA. It runs at a locked 60 fps on anything from an
A9 upward.

On a ProMotion panel (iPhone 13 Pro and later, and every Pro model since) the renderer
automatically raises the frame rate to 120 Hz — see `viewDidAppear` in
`GameViewController`. Because every system in the simulation is delta-time driven, this
needs no tuning: the enemy patrols are pure sine functions of elapsed time, and the frame
delta is clamped to 1/20 s, so physics stays identical at any refresh rate.

On an **iPhone 16 Pro Max** specifically there is a very large amount of headroom left over.
If you want to spend it, the cheapest wins in order are: more sphere tessellation in
`MeshFactory.sphere`, a real shadow pass, and per-pixel rather than per-vertex lighting.

To install over the air on a device you own without re-signing every week, set
`PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` to something unique to you (for example
`com.yourname.topspin`) and use a paid account — Apple rejects duplicate bundle IDs.

---

## Project layout

```
Topspin/
├── project.yml                          XcodeGen manifest
├── build_ipa.sh                         One-shot Mac build → unsigned IPA
├── .github/workflows/build-ipa.yml      Cloud build on a macOS runner
├── .gitignore
├── Resources/Info.plist                 Landscape-only, arm64 + Metal required
└── Sources/
    ├── App/
    │   ├── AppDelegate.swift            Window bootstrap
    │   └── GameViewController.swift     MTKView hosting, HUD, camera pan gesture
    ├── Engine/
    │   ├── Types.swift                  Vertex / Uniforms / DrawItem / InputState
    │   ├── Math.swift                   Right-handed Y-up matrices (Metal depth range)
    │   ├── Mesh.swift                   Procedural box / plane / sphere + GPU buffers
    │   ├── Shaders.metal                Lambert + Blinn-Phong + rim light
    │   └── Renderer.swift               Pipeline, depth state, per-frame submission
    ├── Game/
    │   ├── World.swift                  Course layout, platforms, coins, enemies
    │   ├── Player.swift                 Character state and per-host movement profiles
    │   ├── Camera.swift                 Smoothed third-person orbit camera
    │   └── Game.swift                   Simulation: input, physics, possession, draw list
    └── UI/
        └── TouchControls.swift          Floating stick + two action buttons
```

---

## How the rendering works

The renderer is deliberately minimal — one pipeline, one vertex format, one pass.

**Vertex format.** `position` and `normal`, both `float3`. In both Swift and MSL a `float3`
occupies 16 bytes with 16-byte alignment, so `struct Vertex` is 32 bytes on both sides and
can be shared without any packing tricks.

**Uniforms.** A single 176-byte struct is pushed per draw call with `setVertexBytes` /
`setFragmentBytes`. At this object count, per-draw buffer management would cost more than
it saves. The struct is laid out as two `float4x4` followed by three `float4`, which is
padding-free under 16-byte alignment on both sides.

**Normals under scale.** Platforms are unit boxes scaled to non-uniform sizes, so the
shader transforms normals with the raw model matrix and renormalises. That is only correct
for axis-aligned boxes — which is exactly what all the level geometry is — and it avoids
carrying an inverse-transpose matrix in the uniform block.

**Culling.** Disabled. Every primitive here is a closed convex solid, so back-face culling
saves almost nothing and only invites winding-order bugs. Depth testing does the work.

**Depth range.** Metal's clip space is `[0, 1]`, not OpenGL's `[-1, 1]`, so the projection
matrix in `Math.perspective` uses the Metal convention. Getting this wrong produces
geometry that renders but z-fights or vanishes at distance.

## How the gameplay works

**Ground resolution** is two passes. The vertical pass finds the highest surface at or
below the feet (plus a step tolerance) that the player horizontally overlaps, and snaps to
it — that tolerance is what lets Pip walk up a low ledge without jumping, while platforms
above the feet are ignored so you can pass underneath them. The horizontal pass then pushes
the player out of anything that is a genuine wall, along whichever penetration axis is
shallower, so you slide along surfaces instead of sticking.

**Enemy patrols** are pure sine functions around a home point along a fixed axis. They
cannot drift, cannot desynchronise, and are identical at any frame rate.

**Frame delta** is clamped to 1/20 s. A hitch or a debugger pause would otherwise let the
player tunnel straight through the floor in one step.

---

## Tuning

| Want to change | Where |
| --- | --- |
| Camera orbit direction | Flip the signs in `GameViewController.handleCameraPan` |
| Camera distance / height | `FollowCamera.distance` and `.pitch` |
| Jump and run feel | `Player.moveSpeed` / `.jumpSpeed`, `Game.gravity` |
| Capture range | `Game.captureRadius` |
| Level layout | `World.makeCourse()` |

## License

MIT.
