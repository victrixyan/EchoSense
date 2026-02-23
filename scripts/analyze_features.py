#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///

"""
EchoSense Phase 1.3: Feature Distribution Analysis

Quick analysis script to examine feature distributions and identify
which grouped features have discriminative power between dementia and control groups.

Results Summary:
- Input: 29 grouped features from Phase 1.2
- Metric: Cohen's d effect size (standardized mean difference)
- Findings:
  * Only 1 feature with d >= 0.2 (small effect): articulation_variability (0.233)
  * 8 features with 0.1 <= d < 0.2 (minimal discrimination)
  * 20 features with d < 0.1 (negligible discrimination)
  * articulation_precision_score: d = 0.000 (zero discriminative power)

Recommendation: Remove features with d < 0.10 to reduce noise and dimensionality.
"""

import csv
import math
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


def compute_statistics(values: list[float]) -> dict:
    """Compute basic statistics without numpy."""
    n = len(values)
    if n == 0:
        return {'mean': 0, 'std': 0, 'min': 0, 'max': 0}
    
    mean = sum(values) / n
    variance = sum((x - mean) ** 2 for x in values) / n
    std = math.sqrt(variance)
    
    return {
        'mean': mean,
        'std': std,
        'min': min(values),
        'max': max(values)
    }


def analyze_feature_discrimination(rows: list[dict], feature_name: str) -> dict:
    """
    Analyze how well a feature discriminates between dementia and control.
    
    Returns:
        Dictionary with statistics and discrimination metrics
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
    
    dementia_stats = compute_statistics(dementia_values)
    control_stats = compute_statistics(control_values)
    
    # Compute effect size (Cohen's d) - standardized mean difference
    pooled_std = math.sqrt((dementia_stats['std']**2 + control_stats['std']**2) / 2)
    if pooled_std > 0:
        cohens_d = abs(dementia_stats['mean'] - control_stats['mean']) / pooled_std
    else:
        cohens_d = 0.0
    
    # Compute separation ratio (mean difference relative to pooled variance)
    mean_diff = abs(dementia_stats['mean'] - control_stats['mean'])
    pooled_variance = (dementia_stats['std']**2 + control_stats['std']**2) / 2
    if pooled_variance > 0:
        separation = mean_diff / math.sqrt(pooled_variance)
    else:
        separation = 0.0
    
    # Check if feature has sufficient variance
    overall_values = dementia_values + control_values
    overall_stats = compute_statistics(overall_values)
    cv = overall_stats['std'] / overall_stats['mean'] if overall_stats['mean'] != 0 else 0
    
    return {
        'dementia_mean': dementia_stats['mean'],
        'dementia_std': dementia_stats['std'],
        'control_mean': control_stats['mean'],
        'control_std': control_stats['std'],
        'mean_difference': mean_diff,
        'cohens_d': cohens_d,
        'separation': separation,
        'coefficient_variation': abs(cv)
    }


def main():
    """Analyze feature distributions and discriminative power."""
    project_root = Path(__file__).parent.parent
    features_path = project_root / 'exports' / 'features_grouped.csv'
    
    print("Feature Distribution Analysis")
    print("=" * 80)
    
    fieldnames, rows = load_features(features_path)
    print(f"Loaded {len(rows)} samples\n")
    
    # Analyze each feature (skip filename and label)
    feature_names = [f for f in fieldnames if f not in ['filename', 'label']]
    
    results = []
    for feature in feature_names:
        analysis = analyze_feature_discrimination(rows, feature)
        analysis['feature'] = feature
        results.append(analysis)
    
    # Sort by Cohen's d (effect size) - higher is better discrimination
    results.sort(key=lambda x: x['cohens_d'], reverse=True)
    
    print("Feature Discrimination Ranking (by effect size)")
    print("-" * 80)
    print(f"{'Feature':<35} {'Cohens d':<10} {'Mean Diff':<12} {'CV':<10}")
    print("-" * 80)
    
    for r in results:
        print(f"{r['feature']:<35} {r['cohens_d']:<10.3f} {r['mean_difference']:<12.3f} {r['coefficient_variation']:<10.3f}")
    
    print("\n" + "=" * 80)
    print("Interpretation:")
    print("  Cohen's d: 0.2=small, 0.5=medium, 0.8=large effect")
    print("  CV (Coefficient of Variation): Higher = more variance")
    print("  Features with d < 0.2 may have low discriminative power")
    print("\nRecommendation: Consider removing features with Cohen's d < 0.2")


if __name__ == '__main__':
    main()
