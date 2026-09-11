# Model Evaluation Metrics & Benchmarks

This document defines standard pitch evaluation metrics used to assess model performance against ground-truth dataset annotations.

## Pitch Detection Metrics

### 1. Raw Pitch Accuracy (RPA)
The percentage of voiced frames where the predicted pitch $F0_{pred}$ falls within 50 cents ($\pm 0.5$ semitones) of the ground truth $F0_{gt}$:

$$\text{RPA} = \frac{|\{ i \in \text{Voiced} : |\text{Cents\_Diff}_i| \le 50 \}|}{|\text{Voiced}|} \times 100\%$$

Where cents difference is computed as:
$$\text{Cents\_Diff} = 1200 \times \log_2\left( \frac{F0_{pred}}{F0_{gt}} \right)$$

### 2. Raw Chroma Accuracy (RCA)
Similar to RPA, but measures pitch accuracy modulo octave shifts (useful for detecting octave errors).

### 3. Voiced Recall (VR) & Voiced Precision (VP)
- **Voiced Recall**: Percentage of ground-truth voiced frames correctly predicted as voiced.
- **Voiced Precision**: Percentage of predicted voiced frames that are truly voiced.

### 4. Mean Absolute Cents Error (MACE)
The average absolute error in cents calculated strictly over correctly identified voiced frames:

$$\text{MACE} = \frac{1}{|\text{Voiced}|} \sum_{i \in \text{Voiced}} | \text{Cents\_Diff}_i |$$

## Benchmark Procedure

1. Run inference script `ml/evaluation/evaluate.py` specifying the test metadata path.
2. Predictions and ground-truth annotations are paired frame-by-frame.
3. Compute summary statistics (RPA, RCA, VR, VP, MACE) across all test set recordings.
4. Generate visual pitch contour plots using `ml/evaluation/visualize_results.py`.
