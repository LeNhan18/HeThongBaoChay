import pandas as pd
import matplotlib.pyplot as plt
import os

# File path
csv_path = r'e:\HeThongBaoChay\training_results_20251121_213634\optuna_trials\trial_2\results.csv'
output_path = r'e:\HeThongBaoChay\training_results_20251121_021040\optuna_trials\trial_2\metrics_plot.png'

# Read the CSV file
try:
    df = pd.read_csv(csv_path)
    # Strip whitespace from column names
    df.columns = df.columns.str.strip()
except Exception as e:
    print(f"Error reading CSV: {e}")
    exit(1)

# Create a figure with subplots
fig, axes = plt.subplots(2, 3, figsize=(18, 10))
fig.suptitle('Training Metrics', fontsize=16)

# Plot 1: Box Loss
axes[0, 0].plot(df['epoch'], df['train/box_loss'], label='train/box_loss')
axes[0, 0].plot(df['epoch'], df['val/box_loss'], label='val/box_loss')
axes[0, 0].set_title('Box Loss')
axes[0, 0].set_xlabel('Epoch')
axes[0, 0].set_ylabel('Loss')
axes[0, 0].legend()
axes[0, 0].grid(True)

# Plot 2: Class Loss
axes[0, 1].plot(df['epoch'], df['train/cls_loss'], label='train/cls_loss')
axes[0, 1].plot(df['epoch'], df['val/cls_loss'], label='val/cls_loss')
axes[0, 1].set_title('Class Loss')
axes[0, 1].set_xlabel('Epoch')
axes[0, 1].set_ylabel('Loss')
axes[0, 1].legend()
axes[0, 1].grid(True)

# Plot 3: DFL Loss
axes[0, 2].plot(df['epoch'], df['train/dfl_loss'], label='train/dfl_loss')
axes[0, 2].plot(df['epoch'], df['val/dfl_loss'], label='val/dfl_loss')
axes[0, 2].set_title('DFL Loss')
axes[0, 2].set_xlabel('Epoch')
axes[0, 2].set_ylabel('Loss')
axes[0, 2].legend()
axes[0, 2].grid(True)

# Plot 4: Precision & Recall
axes[1, 0].plot(df['epoch'], df['metrics/precision(B)'], label='Precision(B)')
axes[1, 0].plot(df['epoch'], df['metrics/recall(B)'], label='Recall(B)')
axes[1, 0].set_title('Precision & Recall')
axes[1, 0].set_xlabel('Epoch')
axes[1, 0].set_ylabel('Score')
axes[1, 0].legend()
axes[1, 0].grid(True)

# Plot 5: mAP
axes[1, 1].plot(df['epoch'], df['metrics/mAP50(B)'], label='mAP50(B)')
axes[1, 1].plot(df['epoch'], df['metrics/mAP50-95(B)'], label='mAP50-95(B)')
axes[1, 1].set_title('mAP Scores')
axes[1, 1].set_xlabel('Epoch')
axes[1, 1].set_ylabel('Score')
axes[1, 1].legend()
axes[1, 1].grid(True)

# Plot 6: Learning Rate
axes[1, 2].plot(df['epoch'], df['lr/pg0'], label='lr/pg0')
axes[1, 2].plot(df['epoch'], df['lr/pg1'], label='lr/pg1')
axes[1, 2].plot(df['epoch'], df['lr/pg2'], label='lr/pg2')
axes[1, 2].set_title('Learning Rates')
axes[1, 2].set_xlabel('Epoch')
axes[1, 2].set_ylabel('Learning Rate')
axes[1, 2].legend()
axes[1, 2].grid(True)

plt.tight_layout(rect=[0, 0.03, 1, 0.95])
plt.savefig(output_path)
print(f"Plot saved to {output_path}")
