#!/usr/bin/env python3

import os
import sys
import shutil
import random
import argparse
from pathlib import Path

TARGET_CLASSES = [
    "A", "B", "C", "D", "E", "F", "G", "H", "I",
    "K", "L", "M", "N", "O", "P", "Q", "R", "S",
    "T", "U", "V", "W", "X", "Y", "ILoveYou", "Background"
]

def prepare_dataset(source_dir: str, output_dir: str, train_count: int = 100, test_count: int = 20):
    src = Path(source_dir).expanduser().resolve()
    out = Path(output_dir).expanduser().resolve()

    train_root = out / "Static" / "Train"
    test_root = out / "Static" / "Test"

    print(f"Source: {src}")
    print(f"Output Train: {train_root}")
    print(f"Output Test:  {test_root}")

    for cls in TARGET_CLASSES:
        # Map common Kaggle folder names
        candidate_names = [cls]
        if cls == "Background":
            candidate_names.extend(["nothing", "space", "del", "background", "empty"])

        found_src_dir = None
        for name in candidate_names:
            possible_path = src / name
            if possible_path.exists() and possible_path.is_dir():
                found_src_dir = possible_path
                break
            # Also search subdirectories (e.g. asl_alphabet_train/asl_alphabet_train/A)
            for sub in src.glob(f"**/{name}"):
                if sub.is_dir():
                    found_src_dir = sub
                    break
            if found_src_dir:
                break

        if not found_src_dir:
            print(f"[-] Notice: No source images found in archive for class '{cls}'.")
            if cls == "ILoveYou":
                print("    -> Tip: You can capture 20–30 photos of 'ILoveYou' using our in-app Dataset Capture tool!")
            continue

        images = [f for f in found_src_dir.iterdir() if f.suffix.lower() in [".jpg", ".jpeg", ".png"]]
        if not images:
            print(f"[-] Notice: Class directory '{found_src_dir}' has no image files.")
            continue

        random.shuffle(images)

        needed = train_count + test_count
        selected = images[:needed]

        train_imgs = selected[:train_count]
        test_imgs = selected[train_count:needed]

        (train_root / cls).mkdir(parents=True, exist_ok=True)
        (test_root / cls).mkdir(parents=True, exist_ok=True)

        for img in train_imgs:
            shutil.copy2(img, train_root / cls / img.name)
        for img in test_imgs:
            shutil.copy2(img, test_root / cls / img.name)

        print(f"[+] Class '{cls}': {len(train_imgs)} Train, {len(test_imgs)} Test photos prepared.")

    print("\nDataset preparation complete! You can now load this folder into Create ML (Hand Pose template).")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Organize ASL datasets for Create ML Hand Pose Classification.")
    parser.add_argument("--source", type=str, required=True, help="Path to unzipped raw dataset folder (e.g. ~/Downloads/asl-alphabet)")
    parser.add_argument("--output", type=str, default="~/SignSpeakDataset", help="Destination root path (default: ~/SignSpeakDataset)")
    parser.add_argument("--train-per-class", type=int, default=100, help="Train images per class (default: 100)")
    parser.add_argument("--test-per-class", type=int, default=20, help="Test images per class (default: 20)")
    args = parser.parse_args()

    prepare_dataset(args.source, args.output, args.train_per_class, args.test_per_class)
