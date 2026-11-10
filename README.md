# Extraction Mode PDA Integration

An optional companion mod that places Extraction Mode's interface inside the Extraction tab of the ProjectRPGExpanded Survivor PDA. It also provides an overview dashboard, mission tracking, the PDA start-tab option, and Brazilian Portuguese text based on the PDA's selected language.

## Requirements

- Project Zomboid Build 42.21 or newer.
- [Extraction Mode](https://steamcommunity.com/sharedfiles/filedetails/?id=3785397275).
- [ProjectRPGExpanded](https://steamcommunity.com/sharedfiles/filedetails/?id=3826426915).

The integration checks the PDA methods it uses before installing hooks. If the installed PDA version is incompatible, Extraction Mode's original screens remain available. Administrative and debug actions continue to use Extraction Mode's own permission checks and commands.

The integration is independent of Viewpoint Extraction Support. Install this mod alongside its two requirements to add the PDA interface.

## Features

- Adds an Extraction tab and makes it available as the PDA's initial screen.
- Provides dedicated PDA pages for the overview, upgrades, missions, barter, and garage, with a shared layout and scrolling. Upgrade and mission requirements show item icons and skill book volumes; mission rewards show item icons too.
- Organizes barter contacts in a sidebar with a fixed profile and animated 3D portrait, using the PDA's native portrait and camera-connection effects. Original contact emblems use distinct symbols and hexagonal radio badges. Colors, buttons, camera effects, and crisp item rendering follow the PDA's trader styling. The trust meter follows Extraction Mode's trade and service unlock thresholds, including custom thresholds; it does not add trader discounts or dialogue. Offers appear in a responsive card grid with item/service filters and named service target selectors. Smaller PDA windows use contact tabs to keep every contact accessible.
- Gives Extraction Mode contacts distinct appearances made from vanilla clothing. Portraits appear only in the interface; they do not spawn NPCs or change the world.
- Keeps the original two-column Garage layout, with saved vehicles and trailers beside the preview and controls. Vehicle previews use Extraction Mode's native 3D model when compatible, with its illustration fallback otherwise.
- Routes deployment, invitations, and administrative and debug tools through the PDA's window docking.
- Provides a dashboard with destination selection, raid readiness, hideout generator controls, and a mission summary.
- Shows a contextual board button in Operation Status while Extraction Mode makes boarding available, using its native action.
- Lets each character select an unfinished mission to track, showing its objectives and requirements on the dashboard.
- Shows the requesting contact's emblem on mission cards and waits for the PDA's native loading animation before displaying Extraction content or accepting page input.
- Explains that raids have no fixed end time and shows the next horde or wave timing when Extraction Mode provides it.
- Adds a Zombies category to ProjectRPGExpanded's server settings with per-stage Custom World Danger controls for zombie behavior, perception, infection, and respawn rules.
- Uses the PDA's internal language selection for English and Brazilian Portuguese text.
- Keeps Extraction Mode's native HUD hidden while its interface is active in the PDA, hides the ProjectRPGExpanded player portrait while the world map is open to prevent map icon rendering issues, and keeps the player card behind Ergonomic UI.
- In single-player with the Viewpoint beta, the open PDA uses direct UI rendering so it can update with each game frame. Viewpoint's extra frames resume when the PDA closes.

## Service prices and bank payments

Services and any ordinary barter charging Money use the Survivor PDA trader payment flow: carried cash (including money bundles) first, then an open, enabled bank account. Trades charging both Money and materials still require all material items. Money received as a reward follows Extraction Mode's native cash delivery. The server checks current funds and materials; services also retain their native target and single-use quote validation. A changed service price requires a fresh selection; a native repair failure refunds cash and bank amounts to their original sources.

In **Sandbox Options → Extraction Mode PDA - Services**, configure wound treatment, clothing repair, melee repair, firearm repair and vehicle part repair separately. Defaults match Extraction Mode: $20 for each service except clothing ($10). Prices are whole dollars from 0 to 100,000, with 0 allowing a free service. Each price applies to all native trust tiers of that service. Existing worlds use the defaults until configured.

The sandbox screen also includes these options when its page list was cached before this mod's options registered. Only registered options are added; saved values remain unchanged.

For dedicated servers, install and enable this mod on both the server and clients and configure the server's sandbox options. Prices and funds shown in the PDA come from the server's service snapshot; the client cannot supply the amount to charge. Restart the world/server after installing the addon or adding its sandbox definitions. If the expected PDA payment API is incompatible, supported services are refused rather than charging an incorrect price.

## Local installation

Copy `content\mods\ExtractionModePDA` into `%UserProfile%\Zomboid\mods\ExtractionModePDA`, then enable **Extraction Mode PDA Integration**, **Extraction Mode**, and **ProjectRPGExpanded** in the same game or server configuration and restart the game.

For Workshop packaging, use the `content` folder as the upload content folder. It contains the required `mods\ExtractionModePDA` directory.

## Validation

The source repository's integration specifications use Python with `lupa`'s Lua 5.1 runtime:

```powershell
python tests/run.py --extraction-root <ExtractionMode> --pda-root <ProjectRPGExpanded>
```

The upgrade and mission requirement lists show item icons and the appropriate skill book volume. Barter contacts have a fixed sidebar or compact tabs, and service targets use a named dropdown with the current preview and the original server quote validation. Page scrolling uses a larger step.

The optional ZombieBuddy 2.3.4+ Java helper protects only PDA garage preview scenes. Animated parts wait until their skin transforms are available, then rejoin the native 3D preview. Vehicle scripts and world vehicle models are never changed. Without the helper, unsafe animated models retain the mechanics illustration fallback. Extraction Mode still controls its own Snow/Gore illustration rules and fallback for native failures.

Build the preview helper with `./build.ps1 -ZombieBuddyJar <ZombieBuddy.jar>`. A game restart is required to load the helper. The Lua interface remains available without ZombieBuddy.
