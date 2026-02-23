#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///

"""
Phase 1.2: Clinical Feature Engineering

This script transforms raw eGeMAPS biomarkers into clinically interpretable
grouped features for offline MedGemma reasoning. No statistical normalization
(Z-score, min-max scaling) is applied to maintain full interpretability.

Clinical Rationale:
Neurodegenerative conditions like dementia manifest through specific speech
and voice degradation patterns. Rather than feeding 88 raw acoustic parameters
to the language model, we group related features into clinically meaningful
dimensions that align with observable voice quality changes:

1. PHONATION: Voice production quality (vocal fold vibration)
   - Jitter (frequency instability) increases in neurological disease
   - Shimmer (amplitude instability) increases with coordination loss
   - HNR (harmonics-to-noise ratio) decreases with breathiness/hoarseness

2. PROSODY: Pitch variation and melodic patterns
   - Monotone speech (reduced pitch range) is a dementia hallmark
   - Loss of pitch dynamics reflects emotional flattening
   - Pitch instability indicates motor control degradation

3. RHYTHM: Temporal patterns and speech rate
   - Increased pauses (reduced voiced segments per second)
   - Shorter utterance lengths indicate fragmented speech
   - Temporal variability reflects cognitive planning deficits

4. ENERGY: Vocal intensity and loudness dynamics
   - Reduced loudness is common in Parkinson's and dementia
   - Loss of loudness modulation indicates prosodic impairment
   - Energy variability reflects breath support degradation

5. ARTICULATION: Formant structure and spectral clarity
   - Formant frequencies shift with articulatory precision loss
   - Increased formant bandwidth indicates unclear articulation
   - Spectral tilt changes reflect resonance alterations

6. SPECTRAL_QUALITY: Voice timbre and spectral balance
   - Alpha ratio (high/low frequency balance) changes with age/disease
   - Hammarberg index tracks voice quality degradation
   - MFCC capture overall spectral envelope shape

Aggregation Strategy:
- Use arithmetic mean for central tendency (no median, requires sorting)
- Use difference/range for variability measures
- Use ratios for relative relationships
- Output bounded integers (1-5 scale) for categorical interpretation
"""

import csv
import math
import sys
from pathlib import Path


def load_biomarkers(csv_path: Path) -> tuple[list[str], list[dict]]:
    """
    Load raw eGeMAPS biomarkers from Phase 1 CSV output.
    
    Args:
        csv_path: Path to biomarkers_egeremaps.csv
        
    Returns:
        Tuple of (fieldnames, rows) where rows are dictionaries
    """
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames
        rows = list(reader)
    
    return fieldnames, rows


def safe_float(value: str, default: float = 0.0) -> float:
    """
    Safely convert string to float, handling edge cases.
    
    Args:
        value: String representation of number
        default: Default value if conversion fails
        
    Returns:
        Float value or default
    """
    try:
        return float(value)
    except (ValueError, TypeError):
        return default


def compute_phonation_features(row: dict) -> dict:
    """
    Compute PHONATION quality indicators from voice stability metrics.
    
    Clinical Interpretation:
    - Jitter: Cycle-to-cycle frequency variation (normal: <1%, elevated: >1.5%)
    - Shimmer: Cycle-to-cycle amplitude variation (normal: <0.5 dB, elevated: >1.0 dB)
    - HNR: Harmonics-to-noise ratio (normal: >20 dB, impaired: <15 dB)
    
    Higher jitter/shimmer and lower HNR indicate vocal fold vibration irregularity,
    commonly seen in neurological voice disorders including dementia-related dysarthria.
    
    Args:
        row: Dictionary containing raw eGeMAPS features
        
    Returns:
        Dictionary with grouped phonation features
    """
    # Extract raw jitter and shimmer values
    jitter_mean = safe_float(row.get('jitterLocal_sma3nz_amean', 0))
    jitter_std = safe_float(row.get('jitterLocal_sma3nz_stddevNorm', 0))
    shimmer_mean = safe_float(row.get('shimmerLocaldB_sma3nz_amean', 0))
    shimmer_std = safe_float(row.get('shimmerLocaldB_sma3nz_stddevNorm', 0))
    hnr_mean = safe_float(row.get('HNRdBACF_sma3nz_amean', 0))
    hnr_std = safe_float(row.get('HNRdBACF_sma3nz_stddevNorm', 0))
    
    # Aggregate into stability index (lower is more stable)
    # Jitter and shimmer weighted equally, HNR inverted (high HNR = good)
    vocal_instability = (jitter_mean * 100 + shimmer_mean) - (hnr_mean / 5)
    
    # Voice quality score on 1-5 scale (1=excellent, 5=severely impaired)
    # Thresholds based on clinical literature for voice disorders
    if vocal_instability < 0:
        voice_quality_score = 1
    elif vocal_instability < 2:
        voice_quality_score = 2
    elif vocal_instability < 5:
        voice_quality_score = 3
    elif vocal_instability < 10:
        voice_quality_score = 4
    else:
        voice_quality_score = 5
    
    # Variability indicator (standard deviations combined)
    phonation_variability = jitter_std + shimmer_std + hnr_std
    
    return {
        'phonation_stability': round(vocal_instability, 2),
        'phonation_quality_score': voice_quality_score,
        'phonation_variability': round(phonation_variability, 2),
        'hnr_mean': round(hnr_mean, 2)
    }


def compute_prosody_features(row: dict) -> dict:
    """
    Compute PROSODY characteristics from pitch (F0) dynamics.
    
    Clinical Interpretation:
    - Pitch range: Distance between low and high pitch percentiles
    - Pitch variability: Standard deviation normalized to mean
    - Monotone speech: Reduced pitch range and low variability
    
    Dementia often presents with flat affect and monotone speech due to:
    1. Reduced emotional expressiveness (limbic system involvement)
    2. Motor control deficits (basal ganglia dysfunction)
    3. Cognitive load reducing prosodic planning capacity
    
    Args:
        row: Dictionary containing raw eGeMAPS features
        
    Returns:
        Dictionary with grouped prosody features
    """
    # Extract F0 percentiles (pitch distribution across utterance)
    f0_mean = safe_float(row.get('F0semitoneFrom27.5Hz_sma3nz_amean', 0))
    f0_std = safe_float(row.get('F0semitoneFrom27.5Hz_sma3nz_stddevNorm', 0))
    f0_p20 = safe_float(row.get('F0semitoneFrom27.5Hz_sma3nz_percentile20.0', 0))
    f0_p50 = safe_float(row.get('F0semitoneFrom27.5Hz_sma3nz_percentile50.0', 0))
    f0_p80 = safe_float(row.get('F0semitoneFrom27.5Hz_sma3nz_percentile80.0', 0))
    f0_range = safe_float(row.get('F0semitoneFrom27.5Hz_sma3nz_pctlrange0-2', 0))
    
    # Extract F0 slope features (pitch contour dynamics)
    f0_rise_mean = safe_float(row.get('F0semitoneFrom27.5Hz_sma3nz_meanRisingSlope', 0))
    f0_fall_mean = safe_float(row.get('F0semitoneFrom27.5Hz_sma3nz_meanFallingSlope', 0))
    
    # Pitch range indicator (semitones between 20th and 80th percentile)
    pitch_range = f0_p80 - f0_p20
    
    # Monotone score on 1-5 scale (1=dynamic, 5=monotone)
    # Normal conversational speech: 8-12 semitones range
    # Monotone speech: <5 semitones range
    if pitch_range > 12:
        monotone_score = 1
    elif pitch_range > 8:
        monotone_score = 2
    elif pitch_range > 5:
        monotone_score = 3
    elif pitch_range > 3:
        monotone_score = 4
    else:
        monotone_score = 5
    
    # Pitch dynamics (contour change magnitude)
    pitch_dynamics = abs(f0_rise_mean) + abs(f0_fall_mean)
    
    return {
        'pitch_range_semitones': round(pitch_range, 2),
        'pitch_mean_semitones': round(f0_mean, 2),
        'pitch_variability': round(f0_std, 3),
        'monotone_score': monotone_score,
        'pitch_dynamics': round(pitch_dynamics, 2)
    }


def compute_rhythm_features(row: dict) -> dict:
    """
    Compute RHYTHM and temporal pattern characteristics.
    
    Clinical Interpretation:
    - Voiced segments per second: Speech rate proxy
    - Segment length: Utterance continuity
    - Pause patterns: Cognitive planning deficits
    
    Dementia-related speech shows:
    1. Increased pauses (word-finding difficulties)
    2. Shorter voiced segments (fragmented speech)
    3. Higher temporal variability (inconsistent planning)
    
    These patterns reflect:
    - Lexical retrieval deficits (semantic memory)
    - Working memory constraints (sequence planning)
    - Executive function decline (speech coordination)
    
    Args:
        row: Dictionary containing raw eGeMAPS features
        
    Returns:
        Dictionary with grouped rhythm features
    """
    # Extract temporal segmentation features
    voiced_per_sec = safe_float(row.get('VoicedSegmentsPerSec', 0))
    mean_voiced_len = safe_float(row.get('MeanVoicedSegmentLengthSec', 0))
    std_voiced_len = safe_float(row.get('StddevVoicedSegmentLengthSec', 0))
    mean_unvoiced_len = safe_float(row.get('MeanUnvoicedSegmentLength', 0))
    std_unvoiced_len = safe_float(row.get('StddevUnvoicedSegmentLength', 0))
    
    # Speech continuity: ratio of voiced to unvoiced segment length
    # Higher ratio = more continuous speech
    if mean_unvoiced_len > 0:
        continuity_ratio = mean_voiced_len / mean_unvoiced_len
    else:
        continuity_ratio = mean_voiced_len  # Fallback if no unvoiced segments
    
    # Temporal stability: coefficient of variation for voiced segments
    if mean_voiced_len > 0:
        temporal_stability = std_voiced_len / mean_voiced_len
    else:
        temporal_stability = std_voiced_len
    
    # Fluency score on 1-5 scale (1=fluent, 5=dysfluent)
    # Based on voiced segments per second (normal: 3-5/sec)
    if voiced_per_sec > 4.5:
        fluency_score = 1
    elif voiced_per_sec > 3.5:
        fluency_score = 2
    elif voiced_per_sec > 2.5:
        fluency_score = 3
    elif voiced_per_sec > 1.5:
        fluency_score = 4
    else:
        fluency_score = 5
    
    return {
        'voiced_segments_per_sec': round(voiced_per_sec, 2),
        'speech_continuity_ratio': round(continuity_ratio, 2),
        'temporal_stability': round(temporal_stability, 3),
        'fluency_score': fluency_score,
        'mean_pause_length': round(mean_unvoiced_len, 3)
    }


def compute_energy_features(row: dict) -> dict:
    """
    Compute ENERGY and loudness dynamics.
    
    Clinical Interpretation:
    - Loudness level: Vocal intensity (reflects respiratory-phonatory coordination)
    - Loudness variability: Dynamic range of speech
    - Loudness peaks: Prosodic emphasis capability
    
    Reduced loudness in dementia reflects:
    1. Respiratory weakness (reduced breath support)
    2. Vocal fold atrophy (age and disease)
    3. Reduced prosodic emphasis (flat affect)
    4. Parkinson's overlap (hypophonia)
    
    Args:
        row: Dictionary containing raw eGeMAPS features
        
    Returns:
        Dictionary with grouped energy features
    """
    # Extract loudness statistics
    loud_mean = safe_float(row.get('loudness_sma3_amean', 0))
    loud_std = safe_float(row.get('loudness_sma3_stddevNorm', 0))
    loud_p20 = safe_float(row.get('loudness_sma3_percentile20.0', 0))
    loud_p80 = safe_float(row.get('loudness_sma3_percentile80.0', 0))
    loud_range = safe_float(row.get('loudness_sma3_pctlrange0-2', 0))
    loud_peaks = safe_float(row.get('loudnessPeaksPerSec', 0))
    equiv_spl = safe_float(row.get('equivalentSoundLevel_dBp', 0))
    
    # Dynamic range (difference between loud and soft speech)
    dynamic_range = loud_p80 - loud_p20
    
    # Vocal intensity score on 1-5 scale (1=strong, 5=weak)
    # Based on mean loudness (arbitrary units from openSMILE)
    if loud_mean > 1.0:
        intensity_score = 1
    elif loud_mean > 0.5:
        intensity_score = 2
    elif loud_mean > 0.2:
        intensity_score = 3
    elif loud_mean > 0.1:
        intensity_score = 4
    else:
        intensity_score = 5
    
    return {
        'loudness_mean': round(loud_mean, 3),
        'loudness_dynamic_range': round(dynamic_range, 3),
        'loudness_variability': round(loud_std, 3),
        'loudness_peaks_per_sec': round(loud_peaks, 2),
        'intensity_score': intensity_score
    }


def compute_articulation_features(row: dict) -> dict:
    """
    Compute ARTICULATION precision from formant characteristics.
    
    Clinical Interpretation:
    - Formants (F1, F2, F3): Vocal tract resonances reflecting tongue/jaw position
    - Formant bandwidth: Spectral clarity (narrow = clear, wide = mumbled)
    - Formant variability: Articulatory precision
    
    Dementia-related dysarthria shows:
    1. Reduced formant precision (imprecise articulation)
    2. Increased formant bandwidth (reduced clarity)
    3. Lower formant variability (reduced articulatory range)
    
    These reflect progressive motor control decline affecting:
    - Tongue positioning (F2 especially sensitive)
    - Jaw movement (F1 affected)
    - Velum control (nasality, though not directly measured here)
    
    Args:
        row: Dictionary containing raw eGeMAPS features
        
    Returns:
        Dictionary with grouped articulation features
    """
    # Extract formant frequencies (vocal tract resonances)
    f1_mean = safe_float(row.get('F1frequency_sma3nz_amean', 0))
    f1_std = safe_float(row.get('F1frequency_sma3nz_stddevNorm', 0))
    f2_mean = safe_float(row.get('F2frequency_sma3nz_amean', 0))
    f2_std = safe_float(row.get('F2frequency_sma3nz_stddevNorm', 0))
    f3_mean = safe_float(row.get('F3frequency_sma3nz_amean', 0))
    f3_std = safe_float(row.get('F3frequency_sma3nz_stddevNorm', 0))
    
    # Extract formant bandwidths (spectral clarity indicator)
    f1_bw = safe_float(row.get('F1bandwidth_sma3nz_amean', 0))
    f2_bw = safe_float(row.get('F2bandwidth_sma3nz_amean', 0))
    f3_bw = safe_float(row.get('F3bandwidth_sma3nz_amean', 0))
    
    # Average formant bandwidth (lower = clearer articulation)
    avg_bandwidth = (f1_bw + f2_bw + f3_bw) / 3
    
    # Formant dispersion (vowel space area proxy)
    # Healthy speakers: larger vowel space, greater F2-F1 difference
    formant_dispersion = f2_mean - f1_mean
    
    # Articulatory variability (combined formant standard deviations)
    articulation_variability = f1_std + f2_std + f3_std
    
    # Articulation precision score on 1-5 scale (1=precise, 5=imprecise)
    # Based on average bandwidth (typical: 100-300 Hz)
    if avg_bandwidth < 150:
        precision_score = 1
    elif avg_bandwidth < 250:
        precision_score = 2
    elif avg_bandwidth < 400:
        precision_score = 3
    elif avg_bandwidth < 600:
        precision_score = 4
    else:
        precision_score = 5
    
    return {
        'formant_dispersion_hz': round(formant_dispersion, 1),
        'avg_formant_bandwidth_hz': round(avg_bandwidth, 1),
        'articulation_variability': round(articulation_variability, 3),
        'articulation_precision_score': precision_score
    }


def compute_spectral_quality_features(row: dict) -> dict:
    """
    Compute SPECTRAL QUALITY characteristics from timbre and spectral shape.
    
    Clinical Interpretation:
    - Alpha ratio: High frequency energy (4-5 kHz) vs low (50-1000 Hz)
    - Hammarberg index: Energy below 2 kHz vs above (voice quality)
    - Spectral slope: Tilt of spectrum (source-filter interaction)
    - MFCC: Mel-frequency cepstral coefficients (overall spectral envelope)
    
    Spectral changes in dementia:
    1. Increased alpha ratio (breathier voice, less low-frequency energy)
    2. Altered Hammarberg index (voice quality degradation)
    3. Flatter spectral slope (reduced resonance, weaker harmonics)
    
    These reflect:
    - Incomplete glottal closure (breathiness)
    - Reduced vocal fold tension (weak voice)
    - Poor respiratory-phonatory coordination
    
    Args:
        row: Dictionary containing raw eGeMAPS features
        
    Returns:
        Dictionary with grouped spectral quality features
    """
    # Extract spectral balance metrics (voiced portions only, denoted by "V")
    alpha_ratio = safe_float(row.get('alphaRatioV_sma3nz_amean', 0))
    hammarberg = safe_float(row.get('hammarbergIndexV_sma3nz_amean', 0))
    slope_low = safe_float(row.get('slopeV0-500_sma3nz_amean', 0))
    slope_mid = safe_float(row.get('slopeV500-1500_sma3nz_amean', 0))
    spectral_flux = safe_float(row.get('spectralFluxV_sma3nz_amean', 0))
    
    # Extract MFCC (mel-frequency cepstral coefficients)
    # MFCC 1-4 capture spectral envelope shape (timbre characteristics)
    mfcc1 = safe_float(row.get('mfcc1V_sma3nz_amean', 0))
    mfcc2 = safe_float(row.get('mfcc2V_sma3nz_amean', 0))
    mfcc3 = safe_float(row.get('mfcc3V_sma3nz_amean', 0))
    mfcc4 = safe_float(row.get('mfcc4V_sma3nz_amean', 0))
    
    # Spectral tilt (average of low and mid-frequency slopes)
    spectral_tilt = (slope_low + slope_mid) / 2
    
    # Voice quality indicator (combined alpha ratio and Hammarberg index)
    # Higher values suggest breathier, less efficient phonation
    voice_quality_index = alpha_ratio - hammarberg
    
    # Spectral clarity score on 1-5 scale (1=clear, 5=degraded)
    # Based on alpha ratio (typical: -10 to 5 dB)
    if alpha_ratio < -5:
        clarity_score = 1
    elif alpha_ratio < 0:
        clarity_score = 2
    elif alpha_ratio < 5:
        clarity_score = 3
    elif alpha_ratio < 10:
        clarity_score = 4
    else:
        clarity_score = 5
    
    return {
        'alpha_ratio_db': round(alpha_ratio, 2),
        'hammarberg_index_db': round(hammarberg, 2),
        'spectral_tilt': round(spectral_tilt, 2),
        'voice_quality_index': round(voice_quality_index, 2),
        'spectral_clarity_score': clarity_score,
        'spectral_flux': round(spectral_flux, 4)
    }


def engineer_features(input_csv: Path, output_csv: Path) -> None:
    """
    Main feature engineering pipeline: transform raw biomarkers into clinical groups.
    
    This function implements the Phase 1.2 specification:
    1. Load raw eGeMAPS features from Phase 1
    2. Group related features by clinical domain
    3. Apply minimal arithmetic (mean, diff, ratio)
    4. Generate categorical scores (1-5 scale)
    5. Save to new CSV with interpretable column names
    
    No normalization or statistical transformation is applied to preserve
    interpretability for the offline MedGemma model.
    
    Args:
        input_csv: Path to biomarkers_egeremaps.csv (Phase 1 output)
        output_csv: Path to features_grouped.csv (Phase 1.2 output)
    """
    print("Phase 1.2: Clinical Feature Engineering")
    print("=" * 60)
    print(f"Input: {input_csv}")
    print(f"Output: {output_csv}")
    print("-" * 60)
    
    # Load raw biomarkers
    fieldnames, rows = load_biomarkers(input_csv)
    print(f"Loaded {len(rows)} samples with {len(fieldnames)} raw features")
    
    # Process each row and compute grouped features
    engineered_rows = []
    for idx, row in enumerate(rows, 1):
        # Preserve metadata
        filename = row.get('filename', '')
        label = row.get('label', '')
        
        # Compute clinical feature groups
        phonation = compute_phonation_features(row)
        prosody = compute_prosody_features(row)
        rhythm = compute_rhythm_features(row)
        energy = compute_energy_features(row)
        articulation = compute_articulation_features(row)
        spectral = compute_spectral_quality_features(row)
        
        # Combine into single row
        engineered_row = {
            'filename': filename,
            'label': label,
            **phonation,
            **prosody,
            **rhythm,
            **energy,
            **articulation,
            **spectral
        }
        
        engineered_rows.append(engineered_row)
        
        # Progress indicator
        if idx % 50 == 0 or idx == len(rows):
            print(f"Processed {idx}/{len(rows)} samples", flush=True)
    
    # Write to output CSV
    if not engineered_rows:
        print("Error: No features engineered", file=sys.stderr)
        sys.exit(1)
    
    fieldnames_out = list(engineered_rows[0].keys())
    
    print("-" * 60)
    print(f"Writing {len(engineered_rows)} rows with {len(fieldnames_out)} grouped features...")
    
    with open(output_csv, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames_out)
        writer.writeheader()
        writer.writerows(engineered_rows)
    
    print("Feature engineering complete!")
    print(f"Total grouped features: {len(fieldnames_out) - 2}")  # Exclude metadata
    print("\nFeature groups created:")
    print("  - Phonation: Vocal fold vibration quality")
    print("  - Prosody: Pitch dynamics and melodic patterns")
    print("  - Rhythm: Temporal structure and fluency")
    print("  - Energy: Loudness and intensity dynamics")
    print("  - Articulation: Formant precision and clarity")
    print("  - Spectral Quality: Voice timbre and spectral shape")


def main():
    """
    Execute Phase 1.2 feature engineering pipeline.
    """
    # Define paths relative to project root
    project_root = Path(__file__).parent.parent
    input_csv = project_root / 'exports' / 'biomarkers_egeremaps.csv'
    output_csv = project_root / 'exports' / 'features_grouped.csv'
    
    # Check input exists
    if not input_csv.exists():
        print(f"Error: Input file not found: {input_csv}", file=sys.stderr)
        print("Please run Phase 1 (extract_biomarkers.py) first.", file=sys.stderr)
        sys.exit(1)
    
    # Engineer features
    engineer_features(input_csv, output_csv)


if __name__ == '__main__':
    main()
