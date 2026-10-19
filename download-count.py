#!/usr/bin/env python3
"""Print GitHub-reported integer DMG download counts. Python 3, standard library only."""
import datetime
import json
import os
import sys
import urllib.error
import urllib.request

BASE = "https://api.github.com/repos/engagetal/KCleaner"

def pages(path):
    page = 1
    while True:
        request = urllib.request.Request(
            BASE + path + "?per_page=100&page=" + str(page),
            headers={"Accept": "application/vnd.github+json", "User-Agent": "KCleaner-download-count"},
        )
        token = os.environ.get("GITHUB_TOKEN")
        if token:
            request.add_header("Authorization", "Bearer " + token)
        with urllib.request.urlopen(request, timeout=30) as response:
            values = json.load(response)
        if not isinstance(values, list):
            raise ValueError("Unexpected GitHub API response")
        yield from values
        if len(values) < 100:
            return
        page += 1

def main():
    rows = []
    for release in pages("/releases"):
        if release.get("draft"):
            continue
        for asset in pages("/releases/" + str(release["id"]) + "/assets"):
            if asset["name"].lower().endswith(".dmg"):
                count = asset["download_count"]
                if type(count) is not int or count < 0:
                    raise ValueError("Invalid download count from GitHub")
                rows.append((release["tag_name"], asset["name"], count))
    print("GitHub-reported DMG downloads")
    for tag, name, count in rows:
        print(f"{tag}  {name}: {count}")
    print("TOTAL:", sum(row[2] for row in rows))
    print("Retrieved at:", datetime.datetime.now(datetime.timezone.utc).isoformat())
    print("Counts are downloads, not unique users or installations.")

if __name__ == "__main__":
    try:
        main()
    except (urllib.error.URLError, ValueError, KeyError, TimeoutError) as error:
        print("Could not retrieve a complete count: " + str(error), file=sys.stderr)
        sys.exit(1)
