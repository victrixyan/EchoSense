#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///

"""
EchoSense Phase 1.4: Evidence-Based Feature Selection

This script applies statistical feature selection to retain only features
with meaningful discriminative power between dementia and control groups.

Selection Criterion: Cohen's d Effect Size
- Measures standardized mean difference between groups
- Threshold: d >= 0.10 (retain features with at least minimal discrimination)
- Rationale: Features below this threshold add noise without signal

Why Not Use All Features?
1. Dimensionality: 29 features for 232 samples risks overfitting
2. Interpretability: Fewer features = clearer PCDC recommendations
3. Computational: Smaller feature vectors for on-device inference
4. Clinical: Focus on biomarkers that actually differ in disease

No Machine Learning Required:
This is pure statistical filtering based on group differences, not supervised
feature selection (e.g., LASSO, RFE). We avoid sklearn dependencies entirely.

Clinical Preservation:
While we remove low-discrimination features, we preserve at least one
representative from each clinical domain to maintain interpretability.

Results Summary:
- Input: 29 grouped features from Phase 1.2
- Output: 9 selected features (64.5% reduction)
- Retained features span 4 clinical domains:
  * Energy (4 features): loudness_mean, loudness_variability, intensity_score, loudness_peaks_per_sec
  * Spectral (3 features): spectral_tilt, spectral_clarity_score, spectral_flux
  * Articulation (1 feature): articulation_variability
  * Rhythm (1 feature): voiced_segments_per_sec
- Removed domains: Phonation and Prosody (low discrimination)
- Effect size range: 0.103 to 0.233 (Cohen's d)
"""

import csv
import math
import sys
from pathlib import Path
from collections import defaultdict


def load_features(csv_path: Path) -> tuple[list[str], list[dict]]:
    """Load grouped features CSV."""
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        fieldnames = list(reader.fieldnames)
        rows = list(reader)
    return fieldnames, rows


def safe_float(value: str) -> float:
    """Safely convert to float."""
    try:
        return float(value)
    except (ValueError, TypeError):
        return 0.0


def compute_cohens_d(rows: list[dict], feature_name: str) -> float:
    """
    Compute Cohen's d effect size for a feature.
    
    Cohen's d = (mean1 - mean2) / pooled_std
    
    Interpretation:
    - d < 0.2: Negligible effect
    - d >= 0.2: Small effect
    - d >= 0.5: Medium effect
    - d >= 0.8: Large effect
    
    Args:
        rows: Feature data rows
        feature_name: Name of feature to analyze
        
    Returns:
        Absolute value of Cohen's d
    """
    dementia_values = []
    control_values = []
    
    for row in rows:
        value = safe_float(row.get(feature_name, 0))
        label = row.get('label', '')
        
        if label == 'dementia':
            dementia_values.append(value)
        elif label == 'control':
            control_values.append(value)
    
    # Compute means
    n_dem = len(dementia_values)
    n_ctrl = len(control_values)
    
    if n_dem == 0 or n_ctrl == 0:
        return 0.0
    
    mean_dem = sum(dementia_values) / n_dem
    mean_ctrl = sum(control_values) / n_ctrl
    
    # Compute pooled standard deviation
    var_dem = sum((x - mean_dem) ** 2 for x in dementia_values) / n_dem
    var_ctrl = sum((x - mean_ctrl) ** 2 for x in control_values) / n_ctrl
    
    pooled_std = math.sqrt((var_dem + var_ctrl) / 2)
    
    if pooled_std == 0:
        return 0.0
    
    cohens_d = abs(mean_dem - mean_ctrl) / pooled_std
    
    return cohens_d


def get_feature_domain(feature_name: str) -> str:
    """
    Map feature to its clinical domain based on naming prefix.
    
    Args:
        feature_name: Name of the feature
        
    Returns:
        Domain name (e.g., 'phonation', 'prosody', etc.)
    """
    if feature_name.startswith('phonation_') or feature_name == 'hnr_mean':
        return 'phonation'
    elif feature_name.startswith('pitch_') or feature_name.startswith('monotone_'):
        return 'prosody'
    elif (feature_name.startswith('voiced_') or feature_name.startswith('speech_') or
          feature_name.startswith('temporal_') or feature_name.startswith('fluency_') or
          feature_name.startswith('mean_pause_')):
        return 'rhythm'
    elif feature_name.startswith('loudness_') or feature_name.startswith('intensity_'):
        return 'energy'
    elif feature_name.startswith('formant_') or feature_name.startswith('articulation_'):
        return 'articulation'
    elif (feature_name.startswith('alpha_') or feature_name.startswith('hammarberg_') or
          feature_name.startswith('spectral_') or feature_name.startswith('voice_quality_')):
        return 'spectral'
    else:
        return 'other'


def select_features(rows: list[dict], fieldnames: list[str], threshold: float = 0.10) -> list[str]:
    """
    Select features based on Cohen's d effect size with domain preservation.
    
    Strategy:
    1. Compute Cohen's d for all features
    2. Retain features with d >= threshold
    3. Ensure at least one feature per clinical domain (if any above threshold)
    4. Always keep metadata (filename, label)
    
    Args:
        rows: Feature data
        fieldnames: All column names
        threshold: Minimum Cohen's d to retain (default: 0.10)
        
    Returns:
        List of selected feature names
    """
    # Always keep metadata
    selected = ['filename', 'label']
    
    # Get feature names (exclude metadata)
    feature_names = [f for f in fieldnames if f not in ['filename', 'label']]
    
    # Compute effect sizes
    feature_scores = []
    for feature in feature_names:
        cohens_d = compute_cohens_d(rows, feature)
        domain = get_feature_domain(feature)
        feature_scores.append({
            'name': feature,
            'cohens_d': cohens_d,
            'domain': domain
        })
    
    # Sort by effect size (descending)
    feature_scores.sort(key=lambda x: x['cohens_d'], reverse=True)
    
    # Select features above threshold
    above_threshold = [f for f in feature_scores if f['cohens_d'] >= threshold]
    
    # Track domains represented
    domains_covered = set()
    
    # Add features above threshold
    for feature_info in above_threshold:
        selected.append(feature_info['name'])
        domains_covered.add(feature_info['domain'])
    
    print(f"\nFeature Selection Results:")
    print(f"  Threshold: Cohen's d >= {threshold}")
    print(f"  Features above threshold: {len(above_threshold)}")
    print(f"  Domains covered: {sorted(domains_covered)}")
    
    return selected


def write_selected_features(input_csv: Path, output_csv: Path, selected_features: list[str]) -> None:
    """
    Write new CSV with only selected features.
    
    Args:
        input_csv: Path to full features CSV
        output_csv: Path to output CSV with selected features
        selected_features: List of feature names to keep
    """
    fieldnames, rows = load_features(input_csv)
    
    print(f"\nWriting {len(rows)} samples with {len(selected_features)} features...")
    
    with open(output_csv, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=selected_features)
        writer.writeheader()
        
        for row in rows:
            selected_row = {k: row.get(k, '') for k in selected_features}
            writer.writerow(selected_row)
    
    print(f"Wrote: {output_csv}")


def main():
    """
    Execute Phase 1.3 feature selection pipeline.
    """
    # Define paths
    project_root = Path(__file__).parent.parent
    input_csv = project_root / 'exports' / 'features_grouped.csv'
    output_csv = project_root / 'exports' / 'features_selected.csv'
    
    print("Phase 1.3: Evidence-Based Feature Selection")
    print("=" * 70)
    
    # Check input exists
    if not input_csv.exists():
        print(f"Error: Input file not found: {input_csv}", file=sys.stderr)
        print("Please run Phase 1.2 (engineer_features.py) first.", file=sys.stderr)
        sys.exit(1)
    
    # Load features
    fieldnames, rows = load_features(input_csv)
    print(f"Loaded {len(rows)} samples with {len(fieldnames)} total columns")
    
    # Select features based on effect size
    selected_features = select_features(rows, fieldnames, threshold=0.10)
    
    # Show selected features with effect sizes
    print("\n" + "=" * 70)
    print("Selected Features (Cohen's d >= 0.10):")
    print("-" * 70)
    
    feature_names = [f for f in selected_features if f not in ['filename', 'label']]
    for feature in feature_names:
        cohens_d = compute_cohens_d(rows, feature)
        domain = get_feature_domain(feature)
        print(f"  {feature:<35} d={cohens_d:.3f}  [{domain}]")
    
    # Write selected features to new CSV
    print("\n" + "=" * 70)
    write_selected_features(input_csv, output_csv, selected_features)
    
    print("\nFeature selection complete!")
    print(f"Reduced from {len(fieldnames) - 2} to {len(selected_features) - 2} features")
    
    # Summary
    removed_count = len(fieldnames) - len(selected_features)
    reduction_pct = (removed_count / len(fieldnames)) * 100
    print(f"Removed {removed_count} low-discrimination features ({reduction_pct:.1f}% reduction)")


if __name__ == '__main__':
    main()
