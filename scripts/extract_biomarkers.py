#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "opensmile>=2.6.0",
# ]
# ///

"""
EchoSense Phase 1: Acoustic Biomarker Extraction

This script extracts acoustic biomarkers from audio recordings using the
openSMILE toolkit with the eGeMAPS_v02 (Extended Geneva Minimalistic Acoustic
Parameter Set) feature set. eGeMAPS is a standardized set of acoustic features
designed specifically for health-related voice research and affective computing.

Feature Set: eGeMAPS_v02
Level: Functionals (statistical aggregations over time)

The eGeMAPS feature set includes:
- Frequency-related parameters: F0 (pitch), formants, spectral flux
- Energy/amplitude parameters: loudness, HNR (harmonics-to-noise ratio)
- Spectral parameters: MFCC, alpha ratio, Hammarberg index
- Temporal parameters: jitter, shimmer, duration features

These features capture voice quality degradation patterns commonly observed
in neurodegenerative conditions, including:
- Reduced pitch variability (monotone speech)
- Decreased loudness and energy
- Increased jitter/shimmer (voice instability)
- Altered formant structure (articulatory changes)

Functionals: Statistical aggregates applied to low-level descriptors including
mean, standard deviation, range, percentiles, and temporal derivatives.
"""

import csv
import os
import sys
from pathlib import Path

import opensmile


def get_audio_files(data_dir: Path) -> list[tuple[str, str]]:
    """
    Recursively find all audio files in the data directory structure.
    
    Args:
        data_dir: Root directory containing dementia/nodementia subdirectories
        
    Returns:
        List of tuples: (file_path, label)
        Label is derived from parent directory name (dementia/nodementia)
    """
    audio_files = []
    
    # Define supported audio formats
    audio_extensions = {'.wav', '.mp3', '.flac', '.ogg', '.m4a'}
    
    # Traverse the data directory
    for subdir in ['dementia', 'nodementia']:
        subdir_path = data_dir / subdir
        if not subdir_path.exists():
            print(f"Warning: {subdir_path} does not exist, skipping...", file=sys.stderr)
            continue
            
        # Determine the label based on subdirectory name
        label = 'dementia' if subdir == 'dementia' else 'control'
        
        # Find all audio files in this subdirectory
        for audio_file in subdir_path.iterdir():
            if audio_file.is_file() and audio_file.suffix.lower() in audio_extensions:
                # Only process 'fixed_' files if both versions exist, otherwise use original
                filename = audio_file.name
                if filename.startswith('fixed_'):
                    audio_files.append((str(audio_file), label))
                elif not (audio_file.parent / f"fixed_{filename}").exists():
                    audio_files.append((str(audio_file), label))
    
    return audio_files


def extract_egeremaps_features(audio_files: list[tuple[str, str]], output_csv: Path) -> None:
    """
    Extract eGeMAPS_v02 functionals from audio files and save to CSV.
    
    This function uses openSMILE's pre-configured eGeMAPS_v02 feature set,
    which extracts 88 acoustic parameters at the functional (statistical) level.
    
    Signal Processing Pipeline:
    1. Audio windowing: Frame-based analysis (typically 25ms frames)
    2. Feature extraction: Low-level descriptors (LLDs) computed per frame
    3. Functionals: Statistical aggregations applied over entire utterance
    
    The extraction process is deterministic and follows the eGeMAPS v02
    standard configuration to ensure reproducibility across studies.
    
    Args:
        audio_files: List of (file_path, label) tuples
        output_csv: Path to output CSV file
        
    Output CSV Format:
        - Column 1: filename (basename only)
        - Column 2: label (dementia/control)
        - Columns 3-N: eGeMAPS feature values (88 features)
    """
    # Initialize the openSMILE feature extractor
    # FeatureSet.eGeMAPSv02: Extended Geneva Minimalistic Acoustic Parameter Set v2
    # FeatureLevel.Functionals: Compute statistical aggregates (not frame-level)
    smile = opensmile.Smile(
        feature_set=opensmile.FeatureSet.eGeMAPSv02,
        feature_level=opensmile.FeatureLevel.Functionals,
    )
    
    # Extract features and collect results
    results = []
    total_files = len(audio_files)
    
    print(f"Processing {total_files} audio files...")
    print(f"Feature set: eGeMAPS v02 (Functionals)")
    print(f"Output: {output_csv}")
    print("-" * 60)
    
    for idx, (file_path, label) in enumerate(audio_files, 1):
        try:
            # Extract features from the audio file
            # Returns a pandas DataFrame with one row (functionals computed over entire file)
            features_df = smile.process_file(file_path)
            
            # Convert DataFrame row to dictionary for easier manipulation
            # Drop the 'file' column if it exists in the output
            feature_dict = features_df.iloc[0].to_dict()
            if 'file' in feature_dict:
                del feature_dict['file']
            if 'start' in feature_dict:
                del feature_dict['start']
            if 'end' in feature_dict:
                del feature_dict['end']
            
            # Prepare the result row
            filename = os.path.basename(file_path)
            row = {'filename': filename, 'label': label}
            row.update(feature_dict)
            results.append(row)
            
            # Progress indicator
            print(f"[{idx}/{total_files}] {filename}: {len(feature_dict)} features", flush=True)
            
        except Exception as e:
            # Log errors but continue processing remaining files
            print(f"Error processing {file_path}: {e}", file=sys.stderr)
            continue
    
    # Write results to CSV using standard library (no pandas)
    if not results:
        print("Error: No features extracted successfully", file=sys.stderr)
        sys.exit(1)
    
    # Get all unique feature names (column headers)
    # Start with metadata columns, then add all feature names from first result
    fieldnames = ['filename', 'label'] + [k for k in results[0].keys() if k not in ['filename', 'label']]
    
    print("-" * 60)
    print(f"Writing {len(results)} rows to {output_csv}...")
    
    with open(output_csv, 'w', newline='', encoding='utf-8') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(results)
    
    print(f"Extraction complete!")
    print(f"Total samples: {len(results)}")
    print(f"Total features: {len(fieldnames) - 2}")  # Subtract metadata columns
    
    # Print label distribution
    label_counts = {}
    for row in results:
        label = row['label']
        label_counts[label] = label_counts.get(label, 0) + 1
    print(f"Label distribution: {label_counts}")


def main():
    """
    Main execution pipeline for Phase 1 biomarker extraction.
    """
    # Define paths relative to project root
    project_root = Path(__file__).parent.parent
    data_dir = project_root / 'assets' / 'data'
    output_dir = project_root / 'exports'
    output_csv = output_dir / 'biomarkers_egeremaps.csv'
    
    # Ensure output directory exists
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Step 1: Collect all audio files with their labels
    print("Phase 1: Acoustic Biomarker Extraction")
    print("=" * 60)
    audio_files = get_audio_files(data_dir)
    
    if not audio_files:
        print("Error: No audio files found in data directory", file=sys.stderr)
        sys.exit(1)
    
    # Step 2: Extract eGeMAPS features and save to CSV
    extract_egeremaps_features(audio_files, output_csv)


if __name__ == '__main__':
    main()
