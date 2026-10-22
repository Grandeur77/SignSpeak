#!/usr/bin/env python3
"""
SignSpeak - WLASL Motion Dataset Organizer for Apple Create ML Hand Action Classification.

Filters WLASL video clips for SignSpeak's dynamic motion sign vocabulary:
Hello, ThankYou, Please, Yes, No, Sorry, Water, Good, Mother, Father, J, Z.

Organizes into Create ML training structure:
  ~/SignSpeakDataset/Motion/
    ├── Train/<SignName>/*.mp4
    └── Test/<SignName>/*.mp4
"""

import os
import sys
import json
import shutil
import random
import argparse
import urllib.request
import ssl
from pathlib import Path
from typing import Dict, List, Optional

# Target motion vocabulary for SignSpeak Phase 2
TARGET_GLOSS_MAP: Dict[str, str] = {
    "hello": "Hello",
    "thank you": "ThankYou",
    "thankyou": "ThankYou",
    "please": "Please",
    "yes": "Yes",
    "no": "No",
    "sorry": "Sorry",
    "water": "Water",
    "good": "Good",
    "mother": "Mother",
    "father": "Father",
    "j": "J",
    "z": "Z"
}

def load_wlasl_index(json_path: Path) -> Dict[str, List[dict]]:
    """Loads and filters WLASL_v0.3.json for target vocabulary."""
    if not json_path.exists():
        print(f"[-] Error: Could not find WLASL JSON index at: {json_path}")
        sys.exit(1)

    with open(json_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    target_instances: Dict[str, List[dict]] = {cls_name: [] for cls_name in set(TARGET_GLOSS_MAP.values())}

    for entry in data:
        gloss = entry.get("gloss", "").strip().lower()
        if gloss in TARGET_GLOSS_MAP:
            class_name = TARGET_GLOSS_MAP[gloss]
            for inst in entry.get("instances", []):
                inst_copy = dict(inst)
                inst_copy["class_name"] = class_name
                inst_copy["gloss"] = gloss
                target_instances[class_name].append(inst_copy)

    return target_instances


def download_direct_instance(inst: dict, dest_path: Path) -> bool:
    """Downloads non-YouTube direct MP4 files using standard urllib."""
    url = inst.get("url", "")
    if not url or "youtube" in url or "youtu.be" in url:
        return False

    if dest_path.exists():
        return True

    headers = {
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    }
    if "aslpro" in url:
        headers["Referer"] = "http://www.aslpro.com/cgi-bin/aslpro/aslpro.cgi"

    try:
        ssl_ctx = ssl._create_unverified_context()
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=15, context=ssl_ctx) as response:
            content = response.read()
            if len(content) < 1024:  # Less than 1KB is likely an error HTML page
                return False
            with open(dest_path, "wb") as f:
                f.write(content)
        return True
    except Exception:
        return False


def organize_from_videos_dir(
    target_instances: Dict[str, List[dict]],
    videos_dir: Path,
    output_dir: Path,
    test_ratio: float = 0.2
):
    """Organizes existing video files into Train/ and Test/ per class."""
    train_root = output_dir / "Train"
    test_root = output_dir / "Test"

    stats: Dict[str, Dict[str, int]] = {}

    for class_name, instances in sorted(target_instances.items()):
        class_train = train_root / class_name
        class_test = test_root / class_name
        class_train.mkdir(parents=True, exist_ok=True)
        class_test.mkdir(parents=True, exist_ok=True)

        found_clips: List[tuple[Path, str]] = []  # (src_file, split)

        for inst in instances:
            video_id = inst.get("video_id")
            split = inst.get("split", "train").lower()

            # Check potential file names
            possible_names = [f"{video_id}.mp4", f"{video_id}.mov", f"{video_id}.webm", f"{video_id}.mkv"]
            src_file = None
            for name in possible_names:
                candidate = videos_dir / name
                if candidate.exists() and candidate.stat().st_size > 1024:
                    src_file = candidate
                    break

            if src_file:
                found_clips.append((src_file, split))

        # Copy found clips
        train_count = 0
        test_count = 0

        # If clips have explicit splits, respect them; otherwise do random split
        random.seed(42)
        random.shuffle(found_clips)

        num_test_needed = max(1, int(len(found_clips) * test_ratio)) if len(found_clips) >= 5 else 1

        for i, (clip_path, split) in enumerate(found_clips):
            # Val/test in WLASL goes to Test
            is_test = (split in ["val", "test"]) or (i < num_test_needed and len(found_clips) > 4)
            dst_dir = class_test if is_test else class_train
            dst_file = dst_dir / clip_path.name

            if not dst_file.exists():
                shutil.copy2(clip_path, dst_file)

            if is_test:
                test_count += 1
            else:
                train_count += 1

        stats[class_name] = {"train": train_count, "test": test_count, "total": train_count + test_count}

    return stats


def print_summary_table(stats: Dict[str, Dict[str, int]], output_dir: Path):
    """Prints a formatted summary table of organized datasets."""
    print("\n" + "=" * 65)
    print("  SignSpeak WLASL Motion Dataset Preparation Summary")
    print("=" * 65)
    print(f"{'Sign Class':<16} | {'Train Clips':<12} | {'Test Clips':<12} | {'Total':<8}")
    print("-" * 65)

    total_train = 0
    total_test = 0

    for cls, count_info in sorted(stats.items()):
        tr = count_info["train"]
        te = count_info["test"]
        tot = count_info["total"]
        total_train += tr
        total_test += te
        status_flag = "✓" if tot >= 8 else "!"
        print(f"{cls:<16} | {tr:<12} | {te:<12} | {tot:<8} {status_flag}")

    print("-" * 65)
    print(f"{'TOTAL':<16} | {total_train:<12} | {total_test:<12} | {total_train + total_test:<8}")
    print("=" * 65)
    print(f"\n[✓] Organized dataset location: {output_dir}")
    print(f"    Train folder: {output_dir / 'Train'}")
    print(f"    Test folder:  {output_dir / 'Test'}")
    print("\n[!] Important Next Step:")
    print("    Create ML requires a 'Background' class (random non-signing hand movements).")
    print("    Record ~30 short clips using SignSpeak's in-app Dataset Capture tool")
    print(f"    and place them in: {output_dir / 'Train' / 'Background'}")


def main():
    parser = argparse.ArgumentParser(description="Organize WLASL dataset clips for SignSpeak motion model training.")
    parser.add_argument(
        "--wlasl-dir",
        type=str,
        default="/Users/mileeshafernando/Desktop/SignSpeak Dataset/WLASL",
        help="Path to cloned WLASL directory containing start_kit/WLASL_v0.3.json"
    )
    parser.add_argument(
        "--videos-dir",
        type=str,
        default="",
        help="Path to directory containing downloaded .mp4 video files (e.g. from Kaggle 'wlasl-processed')"
    )
    default_out = "/Users/mileeshafernando/Desktop/SignSpeak Dataset/Dataset- WLASL/Motion"
    if not Path(default_out).parent.exists():
        default_out = "~/SignSpeakDataset/Motion"

    parser.add_argument(
        "--output-dir",
        type=str,
        default=default_out,
        help="Target folder for Create ML dataset"
    )
    parser.add_argument(
        "--download-direct",
        action="store_true",
        help="Attempt direct download of non-YouTube video clips using urllib"
    )

    args = parser.parse_args()

    wlasl_dir = Path(args.wlasl_dir).expanduser().resolve()
    json_path = wlasl_dir / "start_kit" / "WLASL_v0.3.json"
    output_dir = Path(args.output_dir).expanduser().resolve()

    print(f"[i] Loading WLASL Index from: {json_path}")
    target_instances = load_wlasl_index(json_path)

    total_target_instances = sum(len(v) for v in target_instances.values())
    print(f"[✓] Found {len(target_instances)} target classes covering {total_target_instances} video instances.")

    # Determine videos source directory
    videos_dir: Optional[Path] = None
    if args.videos_dir:
        candidate = Path(args.videos_dir).expanduser().resolve()
        if candidate.exists() and candidate.is_dir():
            videos_dir = candidate

    # Check common locations if not provided
    if not videos_dir:
        for possible in [
            wlasl_dir / "start_kit" / "videos",
            wlasl_dir / "videos",
            wlasl_dir.parent / "videos",
            wlasl_dir.parent / "wlasl-processed" / "videos"
        ]:
            if possible.exists() and possible.is_dir():
                videos_dir = possible
                break

    # If --download-direct requested, download non-YouTube clips to a local cache
    if args.download_direct or not videos_dir:
        cache_dir = wlasl_dir / "direct_downloads"
        cache_dir.mkdir(parents=True, exist_ok=True)

        if args.download_direct:
            print(f"\n[i] Downloading direct (non-YouTube) video clips to {cache_dir}...")
            downloaded = 0
            for cls_name, insts in target_instances.items():
                for inst in insts:
                    v_id = inst.get("video_id")
                    dest = cache_dir / f"{v_id}.mp4"
                    if download_direct_instance(inst, dest):
                        downloaded += 1
                        print(f"    [+] {cls_name}: Saved {v_id}.mp4")
            print(f"[✓] Downloaded {downloaded} direct clips.")

        if cache_dir.exists() and any(cache_dir.iterdir()):
            videos_dir = cache_dir

    if not videos_dir:
        print("\n[-] Notice: No downloaded video files (.mp4) were found yet.")
        print("\nTo get the video files easily, choose one of these two options:")
        print("  Option A (Recommended - Instant):")
        print("    1. Download the pre-processed WLASL videos from Kaggle:")
        print("       https://www.kaggle.com/datasets/risangbaskoro/wlasl-processed")
        print("    2. Unzip and run this script pointing to the 'videos' folder:")
        print(f"       python3 scripts/prepare_motion_dataset.py --videos-dir /path/to/extracted/videos\n")
        print("  Option B (Direct automatic download of 110+ web clips):")
        print("    Run this script with the --download-direct flag:")
        print(f"       python3 scripts/prepare_motion_dataset.py --download-direct\n")
        sys.exit(0)

    print(f"\n[i] Organizing clips from: {videos_dir}")
    stats = organize_from_videos_dir(target_instances, videos_dir, output_dir)
    print_summary_table(stats, output_dir)


if __name__ == "__main__":
    main()
