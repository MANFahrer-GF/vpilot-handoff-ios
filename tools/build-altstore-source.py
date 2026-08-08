#!/usr/bin/env python3
"""Regenerate docs/source.json from the repository's GitHub releases.

An AltStore/SideStore *source* is a JSON file users add once by URL. From then
on the app shows up in their sideloader's browse list and new releases arrive as
update badges, instead of everyone having to notice a release page and drag an
.ipa around. It costs nothing and needs no Apple account.

Run after publishing a release:

    python3 tools/build-altstore-source.py

Version, size and date are read back from the published release assets, so the
file can't drift from what is actually downloadable.
"""

import json
import pathlib
import subprocess
import sys

REPO = "MANFahrer-GF/vpilot-handoff-ios"
RAW = f"https://raw.githubusercontent.com/{REPO}/main"
OUT = pathlib.Path(__file__).resolve().parent.parent / "docs" / "source.json"

SUBTITLE = "VATSIM controllers, chat and radio on the iPad"

# Shown in the sideloader's listing, in this order. Names are checked against
# docs/screenshots below, so a renamed file fails the build instead of leaving a
# broken image in the store listing.
SHOTS = [
    "dashboard-wide",
    "dashboard-dark",
    "narrow-chat",
    "status-expanded",
    "controller-tune",
    "frequency-tune",
    "settings",
    "theme-editor",
]

DESCRIPTION = """\
An unofficial iPad client for the Handoff vPilot plugin by sushi.at — the VATSIM \
controller list, chat and radio panel on a second screen, next to your charts in \
Split View.

Not affiliated with, endorsed by, or maintained by sushi.at, VATSIM or vPilot. \
Report problems with this app on its own GitHub repository, not upstream.

• Controller list ranked by the plugin, colour-coded per facility, with VATSIM \
rating, pin, chat and one-tap tuning to COM1, COM2 or standby.
• Radio panel — COM1/COM2 active and standby, transmit and receive selection and \
transponder, mirrored live from SimConnect. Tuning from the iPad writes back to \
the sim.
• Chat with radio and private conversations as separate tabs, unread badges, and \
calls naming your own callsign highlighted.
• Flight-plan cross-check against SimBrief and VATSIM.
• Editable per-facility colour themes, including colourblind-safe presets.
• 8.33 kHz and 25 kHz channel spacing.

Requires the Handoff plugin running in vPilot on a PC on the same network, with \
TCP 48765 and UDP 48766 open. The iPad talks to that PC and nothing else: no \
account, no analytics, no server. The plugin's certificate is pinned on first \
pairing and the token lives in the Keychain."""


def releases():
    out = subprocess.run(
        ["gh", "release", "list", "--repo", REPO, "--json",
         "tagName,publishedAt,isDraft,isPrerelease"],
        capture_output=True, text=True, check=True,
    ).stdout
    return [r for r in json.loads(out) if not r["isDraft"]]


def version_entry(release):
    detail = json.loads(subprocess.run(
        ["gh", "release", "view", release["tagName"], "--repo", REPO,
         "--json", "assets,body"],
        capture_output=True, text=True, check=True,
    ).stdout)

    ipa = next((a for a in detail["assets"] if a["name"].endswith(".ipa")), None)
    if ipa is None:
        # A release without an .ipa is nothing a sideloader can install; listing
        # it would show users an update they cannot get.
        print(f"  skipping {release['tagName']}: no .ipa attached", file=sys.stderr)
        return None

    return {
        "version": release["tagName"].lstrip("v"),
        "date": release["publishedAt"],
        "localizedDescription": detail["body"].strip()[:4000],
        "downloadURL": ipa["url"],
        "size": ipa["size"],
        "minOSVersion": "17.0",
    }


def main():
    shots_dir = OUT.parent / "screenshots"
    missing = [s for s in SHOTS if not (shots_dir / f"{s}.png").exists()]
    if missing:
        sys.exit(f"screenshots missing from {shots_dir}: {', '.join(missing)}")

    versions = [v for v in (version_entry(r) for r in releases()) if v]
    if not versions:
        sys.exit("no published release with an .ipa -- nothing to list")

    source = {
        "name": "Handoff for iPad",
        "identifier": "com.thomaskant.handoff.source",
        "subtitle": SUBTITLE,
        "website": f"https://github.com/{REPO}",
        "iconURL": f"{RAW}/Handoff/Assets.xcassets/AppIcon.appiconset/icon-1024.png",
        "tintColor": "2CC5BF",
        "apps": [{
            "name": "Handoff for iPad",
            "bundleIdentifier": "com.thomaskant.handoff",
            "developerName": "Thomas Kant",
            "subtitle": SUBTITLE,
            "localizedDescription": DESCRIPTION,
            "iconURL": f"{RAW}/Handoff/Assets.xcassets/AppIcon.appiconset/icon-1024.png",
            "tintColor": "2CC5BF",
            "category": "utilities",
            "screenshotURLs": [
                f"{RAW}/docs/screenshots/{name}.png" for name in SHOTS
            ],
            "versions": versions,
            "appPermissions": {
                "entitlements": [],
                "privacy": [{
                    "name": "LocalNetwork",
                    "usageDescription":
                        "Connects to the vPilot plugin on your own PC. Nothing "
                        "leaves your network.",
                }],
            },
        }],
        "news": [],
    }

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(source, indent=2) + "\n")
    print(f"wrote {OUT} with {len(versions)} version(s): "
          + ", ".join(v["version"] for v in versions))


if __name__ == "__main__":
    main()
