# Digitization-of-ECG-Signals
A Method for Transforming ECG Signal Waveforms into Digitalized Features

A MATLAB-based method for transforming raw ECG (electrocardiogram) signal waveforms into structured, digitized features — including automated detection of P, Q, R, S, and T fiducial points, heart-rate statistics, and K-means–driven removal of abnormal beats.

## Overview

This project provides a single-pipeline MATLAB tool (`M3_ECG_calculate_pro`) that takes a single-lead ECG signal and automatically:

- **Preprocesses** the signal (removes NaN values, mean-centers it, detects and corrects polarity inversion)
- **Detects the QRS complex** using a `wjqrs`-based R-peak detector refined by `qrs_adjust`, then locates Q and S points via gradient search
- **Rejects abnormal beats** with two K-means clustering stages (clustering on RR-interval statistics and on QR-amplitude statistics) to eliminate missed and spurious detections
- **Localizes P and T waves** proportionally to the RR interval around each R peak
- **Extracts digitized features** — R-peak indices, RR intervals, heart rate, ST-segment slope/amplitude statistics, and more — returned as structured MATLAB data
- **Optionally visualizes** the detected fiducial points overlaid on the original waveform for manual verification

## Requirements

- MATLAB R2016b or later
- Statistics and Machine Learning Toolbox (for `kmeans`, `tabulate`)
- Signal Processing Toolbox (for `findpeaks`)

> **Note:** `M3_ECG_calculate_pro.m` calls several helper functions (`wjqrs`, `qrs_adjust`, `pQrst_point_locs`, `M3_ECG_c_subfunc_0`, `M3_ECG_c_subfunc_1`, `M3_ECG_c_subfilter_2`). These are **not included in this repository yet** — see the *TODO* section below.

## Repository Structure

| File | Description |
| --- | --- |
| `M3_ECG_calculate_pro.m` | Main function: ECG loading, fiducial-point detection, feature extraction, and artifact removal |

## Usage

### Function signature

