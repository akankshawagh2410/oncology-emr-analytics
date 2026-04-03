#!/usr/bin/env python3
"""
setup_data.py
─────────────
Downloads and runs Synthea to generate synthetic EMR data for the project.
Run this FIRST before opening any notebooks.

Usage:
    python scripts/setup_data.py --patients 1000

Requirements:
    - Java 11+ installed  (check: java -version)
    - Internet connection for first run (downloads Synthea jar ~50MB)
"""

import subprocess
import urllib.request
import os
import argparse
import sys

SYNTHEA_VERSION = "3.2.0"
SYNTHEA_JAR     = f"synthea-with-dependencies.jar"
SYNTHEA_URL     = (
    f"https://github.com/synthetichealth/synthea/releases/download/"
    f"master-branch-latest/{SYNTHEA_JAR}"
)

DATA_RAW_DIR = os.path.join(os.path.dirname(__file__), '..', 'data', 'raw')
FIGURES_DIR  = os.path.join(os.path.dirname(__file__), '..', 'figures')


def check_java():
    try:
        result = subprocess.run(['java', '-version'], capture_output=True, text=True)
        print(f"✓ Java found: {result.stderr.splitlines()[0]}")
        return True
    except FileNotFoundError:
        print("✗ Java not found. Please install Java 11+:")
        print("  macOS  : brew install openjdk@11")
        print("  Ubuntu : sudo apt install default-jdk")
        print("  Windows: https://adoptium.net/")
        return False


def download_synthea():
    if os.path.exists(SYNTHEA_JAR):
        print(f"✓ {SYNTHEA_JAR} already exists, skipping download.")
        return
    print(f"Downloading Synthea {SYNTHEA_VERSION} (~50MB)...")
    urllib.request.urlretrieve(SYNTHEA_URL, SYNTHEA_JAR,
        reporthook=lambda b, bs, ts: print(
            f"\r  {min(b*bs, ts)/(1024*1024):.1f} / {ts/(1024*1024):.1f} MB", end=""
        )
    )
    print(f"\n✓ Downloaded {SYNTHEA_JAR}")


def generate_data(n_patients: int, state: str = "Washington", city: str = "Seattle"):
    os.makedirs(DATA_RAW_DIR, exist_ok=True)
    os.makedirs(FIGURES_DIR,  exist_ok=True)

    # Synthea modules to enable (oncology + core)
    cmd = [
        'java', '-jar', SYNTHEA_JAR,
        '--exporter.csv.export=true',
        f'--exporter.baseDirectory={os.path.abspath(DATA_RAW_DIR)}/..',
        '-p', str(n_patients),
        state, city
    ]

    print(f"\nGenerating {n_patients} synthetic patients in {city}, {state}...")
    print("This takes ~2 min for 1000 patients.\n")

    result = subprocess.run(cmd, text=True, capture_output=False)
    if result.returncode == 0:
        print(f"\n✓ Synthea complete. CSVs written to: data/raw/")
        list_generated_files()
    else:
        print("\n✗ Synthea failed. Check Java version (needs 11+).")
        sys.exit(1)


def list_generated_files():
    # Synthea writes to output/csv by default; move to data/raw
    synthea_out = os.path.join(
        os.path.dirname(__file__), '..', 'data', '..', 'output', 'csv'
    )
    if os.path.exists(synthea_out):
        files = os.listdir(synthea_out)
        print("\nGenerated files:")
        for f in sorted(files):
            path = os.path.join(synthea_out, f)
            size_kb = os.path.getsize(path) / 1024
            print(f"  {f:35s} {size_kb:>8.1f} KB")
    else:
        # Check data/raw directly
        if os.path.exists(DATA_RAW_DIR):
            files = [f for f in os.listdir(DATA_RAW_DIR) if f.endswith('.csv')]
            for f in sorted(files):
                path = os.path.join(DATA_RAW_DIR, f)
                size_kb = os.path.getsize(path) / 1024
                print(f"  {f:35s} {size_kb:>8.1f} KB")


def verify_required_files():
    required = ['patients.csv', 'encounters.csv', 'conditions.csv',
                'observations.csv', 'medications.csv']
    missing = [f for f in required
               if not os.path.exists(os.path.join(DATA_RAW_DIR, f))]
    if missing:
        print(f"\n⚠ Missing files in data/raw/: {missing}")
        print("  Synthea may have written to output/csv/ instead.")
        print("  Move the CSV files into data/raw/ manually, then re-run notebooks.")
    else:
        print(f"\n✓ All required CSVs present in data/raw/")
        print("  → Open notebooks/01_eda_synthea.ipynb to begin analysis.")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Set up Synthea EMR data for project.')
    parser.add_argument('--patients', type=int, default=1000,
                        help='Number of synthetic patients to generate (default: 1000)')
    parser.add_argument('--state',   type=str, default='Washington')
    parser.add_argument('--city',    type=str, default='Seattle')
    args = parser.parse_args()

    print("=" * 55)
    print("  Oncology EMR Analytics — Data Setup")
    print("=" * 55)

    if not check_java():
        sys.exit(1)

    download_synthea()
    generate_data(args.patients, args.state, args.city)
    verify_required_files()
