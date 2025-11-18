"""
Quick training script với best practices cơ bản cho YOLOv8 Fire & Smoke Detection
Phiên bản đơn giản và dễ sử dụng
"""

import os
import yaml
import torch
import matplotlib.pyplot as plt
import seaborn as sns
import pandas as pd
from ultralytics import YOLO
import numpy as np
from datetime import datetime
import warnings

warnings.filterwarnings("ignore")

class QuickFireSmokeTrainer:
    def __init__(self, 
                 data_path="data/data.yaml", 
                 model_size="yolov8s", 
                 epochs=100,
                 img_size=640):
        """
        Quick trainer với best practices cơ bản
        
        Args:
            data_path: Đường dẫn file data.yaml
            model_size: Kích thước model (yolov8n, yolov8s, yolov8m, yolov8l, yolov8x)
            epochs: Số epochs training
            img_size: Kích thước ảnh input
        """
        self.data_path = data_path
        self.model_size = model_size
        self.epochs = epochs
        self.img_size = img_size
        
        # Setup directories
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.results_dir = f"quick_results_{timestamp}"
        self.plots_dir = os.path.join(self.results_dir, "plots")
        os.makedirs(self.plots_dir, exist_ok=True)
        
        # Setup device
        self.device = 'cuda' if torch.cuda.is_available() else 'cpu'
        print(f"🔥 Using device: {self.device}")
        
        # Calculate optimal batch size
        self.batch_size = self._get_optimal_batch_size()
        
        # Load model
        self.model = YOLO(f'{model_size}.pt')
        print(f"🎯 Loaded model: {model_size}")
        
    def _get_optimal_batch_size(self):
        """Tính batch size tối ưu dựa trên GPU memory"""
        if 'cuda' in self.device:
            try:
                gpu_memory = torch.cuda.get_device_properties(0).total_memory / 1024**3
                
                # Batch size mapping based on model and GPU memory
                size_batch_map = {
                    'yolov8n': min(32, max(8, int(gpu_memory * 4))),
                    'yolov8s': min(24, max(6, int(gpu_memory * 3))),
                    'yolov8m': min(16, max(4, int(gpu_memory * 2))),
                    'yolov8l': min(12, max(2, int(gpu_memory * 1.5))),
                    'yolov8x': min(8, max(1, int(gpu_memory * 1)))
                }
                
                batch_size = size_batch_map.get(self.model_size, 16)
                print(f"🧮 Auto batch size: {batch_size} (GPU: {gpu_memory:.1f}GB)")
                return batch_size
            except:
                return 16
        else:
            return 8
    
    def verify_data(self):
        """Kiểm tra dữ liệu"""
        print("📊 Verifying dataset...")
        
        with open(self.data_path, 'r') as f:
            data_config = yaml.safe_load(f)
        
        base_dir = os.path.dirname(self.data_path)
        
        for split in ['train', 'val', 'test']:
            if split in data_config:
                img_path = os.path.join(base_dir, data_config[split])
                label_path = img_path.replace('images', 'labels') 
                
                if os.path.exists(img_path):
                    img_count = len([f for f in os.listdir(img_path) 
                                   if f.lower().endswith(('.jpg', '.jpeg', '.png'))])
                    
                    if os.path.exists(label_path):
                        label_count = len([f for f in os.listdir(label_path) 
                                         if f.endswith('.txt')])
                    else:
                        label_count = 0
                    
                    print(f"  {split}: {img_count} images, {label_count} labels")
        
        print(f"  Classes: {data_config['names']}")
        return data_config
    
    def train_with_best_practices(self):
        """Training với best practices được tối ưu"""
        print(f"🚀 Starting training for {self.epochs} epochs...")
        
        # Optimized training parameters
        train_args = {
            # Basic settings
            'data': self.data_path,
            'epochs': self.epochs,
            'imgsz': self.img_size,
            'batch': self.batch_size,
            'device': self.device,
            'workers': min(8, os.cpu_count()),
            
            # Output settings
            'project': self.results_dir,
            'name': 'fire_smoke_detection',
            'save': True,
            'save_period': 25,
            'plots': True,
            'val': True,
            'cache': True,
            
            # Optimization settings
            'optimizer': 'AdamW',              # AdamW optimizer
            'lr0': 0.01,                       # Initial learning rate
            'lrf': 0.01,                       # Final learning rate
            'momentum': 0.937,                 # Momentum
            'weight_decay': 0.0005,            # Weight decay
            'warmup_epochs': 3,                # Warmup epochs
            'patience': 30,                    # Early stopping patience
            'amp': True,                       # Mixed precision
            'cos_lr': True,                    # Cosine LR scheduler
            'close_mosaic': 15,                # Close mosaic in last N epochs
            
            # Loss gains (optimized for fire/smoke detection)
            'box': 7.5,                        # Box regression loss gain
            'cls': 0.5,                        # Classification loss gain
            'dfl': 1.5,                        # Distribution focal loss gain
            
            # Data augmentation (enhanced for fire/smoke)
            'hsv_h': 0.015,                    # HSV-Hue augmentation
            'hsv_s': 0.7,                      # HSV-Saturation augmentation
            'hsv_v': 0.4,                      # HSV-Value augmentation
            'degrees': 10.0,                   # Rotation degrees
            'translate': 0.1,                  # Translation fraction
            'scale': 0.9,                      # Scale factor
            'shear': 2.0,                      # Shear degrees
            'perspective': 0.0,                # Perspective transform
            'flipud': 0.0,                     # Vertical flip probability
            'fliplr': 0.5,                     # Horizontal flip probability
            'mosaic': 1.0,                     # Mosaic probability
            'mixup': 0.15,                     # Mixup probability
            'copy_paste': 0.3,                 # Copy-paste probability
        }
        
        print("🔧 Training configuration:")
        print(f"   Model: {self.model_size}")
        print(f"   Batch size: {self.batch_size}")
        print(f"   Image size: {self.img_size}")
        print(f"   Mixed precision: {train_args['amp']}")
        print(f"   Optimizer: {train_args['optimizer']}")
        
        # Start training
        self.results = self.model.train(**train_args)
        
        print("✅ Training completed!")
        return self.results
    
    def plot_results(self):
        """Vẽ biểu đồ kết quả training"""
        print("📊 Creating result plots...")
        
        run_dir = self.results.save_dir
        results_csv = os.path.join(run_dir, 'results.csv')
        
        if not os.path.exists(results_csv):
            print("❌ Results file not found")
            return
        
        # Read results
        df = pd.read_csv(results_csv)
        df.columns = df.columns.str.strip()
        
        # Create comprehensive plot
        fig, axes = plt.subplots(2, 3, figsize=(18, 12))
        fig.suptitle('🔥💨 YOLOv8 Fire & Smoke Detection Training Results', 
                    fontsize=16, fontweight='bold')
        
        # 1. Training & Validation Losses
        ax1 = axes[0, 0]
        if 'train/box_loss' in df.columns:
            ax1.plot(df.index, df['train/box_loss'], 'r-', label='Train Box', linewidth=2)
        if 'val/box_loss' in df.columns:
            ax1.plot(df.index, df['val/box_loss'], 'r--', label='Val Box', linewidth=2)
        if 'train/cls_loss' in df.columns:
            ax1.plot(df.index, df['train/cls_loss'], 'b-', label='Train Cls', linewidth=2)
        if 'val/cls_loss' in df.columns:
            ax1.plot(df.index, df['val/cls_loss'], 'b--', label='Val Cls', linewidth=2)
        ax1.set_title('📉 Loss Curves')
        ax1.set_xlabel('Epoch')
        ax1.set_ylabel('Loss')
        ax1.legend()
        ax1.grid(True, alpha=0.3)
        
        # 2. mAP Metrics
        ax2 = axes[0, 1]
        if 'metrics/mAP50(B)' in df.columns:
            ax2.plot(df.index, df['metrics/mAP50(B)'], 'g-', 
                    label='mAP@0.5', linewidth=3, marker='o', markersize=4)
        if 'metrics/mAP50-95(B)' in df.columns:
            ax2.plot(df.index, df['metrics/mAP50-95(B)'], 'darkgreen', 
                    label='mAP@0.5:0.95', linewidth=3, marker='s', markersize=4)
        ax2.set_title('🎯 Mean Average Precision')
        ax2.set_xlabel('Epoch')
        ax2.set_ylabel('mAP')
        ax2.legend()
        ax2.grid(True, alpha=0.3)
        ax2.set_ylim(0, 1)
        
        # 3. Precision & Recall
        ax3 = axes[0, 2]
        if 'metrics/precision(B)' in df.columns:
            ax3.plot(df.index, df['metrics/precision(B)'], 'purple', 
                    label='Precision', linewidth=2, marker='^', markersize=3)
        if 'metrics/recall(B)' in df.columns:
            ax3.plot(df.index, df['metrics/recall(B)'], 'orange', 
                    label='Recall', linewidth=2, marker='v', markersize=3)
        ax3.set_title('🔍 Precision & Recall')
        ax3.set_xlabel('Epoch')
        ax3.set_ylabel('Score')
        ax3.legend()
        ax3.grid(True, alpha=0.3)
        ax3.set_ylim(0, 1)
        
        # 4. Learning Rate
        ax4 = axes[1, 0]
        lr_cols = [col for col in df.columns if 'lr' in col.lower()]
        for col in lr_cols:
            ax4.plot(df.index, df[col], label=col, linewidth=2)
        ax4.set_title('📈 Learning Rate Schedule')
        ax4.set_xlabel('Epoch')
        ax4.set_ylabel('Learning Rate')
        ax4.legend()
        ax4.grid(True, alpha=0.3)
        ax4.set_yscale('log')
        
        # 5. F1 Score
        ax5 = axes[1, 1]
        if 'metrics/precision(B)' in df.columns and 'metrics/recall(B)' in df.columns:
            precision = df['metrics/precision(B)']
            recall = df['metrics/recall(B)']
            f1_score = 2 * (precision * recall) / (precision + recall + 1e-16)
            ax5.plot(df.index, f1_score, 'red', linewidth=3, marker='D', markersize=4)
            ax5.fill_between(df.index, f1_score, alpha=0.2, color='red')
        ax5.set_title('🎯 F1 Score')
        ax5.set_xlabel('Epoch')
        ax5.set_ylabel('F1 Score')
        ax5.grid(True, alpha=0.3)
        ax5.set_ylim(0, 1)
        
        # 6. Model Performance Summary
        ax6 = axes[1, 2]
        last_epoch = df.iloc[-1]
        
        metrics_names = ['mAP@0.5', 'mAP@0.5:0.95', 'Precision', 'Recall']
        metrics_values = []
        
        if 'metrics/mAP50(B)' in df.columns:
            metrics_values.append(last_epoch['metrics/mAP50(B)'])
        else:
            metrics_values.append(0)
            
        if 'metrics/mAP50-95(B)' in df.columns:
            metrics_values.append(last_epoch['metrics/mAP50-95(B)'])
        else:
            metrics_values.append(0)
            
        if 'metrics/precision(B)' in df.columns:
            metrics_values.append(last_epoch['metrics/precision(B)'])
        else:
            metrics_values.append(0)
            
        if 'metrics/recall(B)' in df.columns:
            metrics_values.append(last_epoch['metrics/recall(B)'])
        else:
            metrics_values.append(0)
        
        colors = ['#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4']
        bars = ax6.bar(metrics_names, metrics_values, color=colors, alpha=0.8)
        
        ax6.set_title('📊 Final Performance')
        ax6.set_ylabel('Score')
        ax6.set_ylim(0, 1)
        ax6.grid(True, alpha=0.3, axis='y')
        
        # Add value labels on bars
        for bar, value in zip(bars, metrics_values):
            height = bar.get_height()
            ax6.text(bar.get_x() + bar.get_width()/2., height + 0.01,
                    f'{value:.3f}', ha='center', va='bottom', fontweight='bold')
        
        plt.tight_layout()
        
        # Save plot
        plot_path = os.path.join(self.plots_dir, 'training_results.png')
        plt.savefig(plot_path, dpi=300, bbox_inches='tight')
        print(f"💾 Results plot saved: {plot_path}")
        plt.show()
    
    def evaluate_model(self):
        """Đánh giá model"""
        print("🧪 Evaluating model...")
        
        # Validate on test set
        metrics = self.model.val(data=self.data_path, split='test')
        
        print("📋 Final Results:")
        print(f"  🎯 mAP@0.5: {metrics.box.map50:.4f}")
        print(f"  🎯 mAP@0.5:0.95: {metrics.box.map:.4f}")
        print(f"  🔍 Precision: {metrics.box.mp:.4f}")
        print(f"  🔍 Recall: {metrics.box.mr:.4f}")
        
        return metrics
    
    def run_quick_training(self):
        """Chạy toàn bộ quy trình training nhanh"""
        print("🚀 Starting quick training pipeline...")
        
        try:
            # 1. Verify data
            data_config = self.verify_data()
            
            # 2. Train model
            results = self.train_with_best_practices()
            
            # 3. Plot results
            self.plot_results()
            
            # 4. Evaluate model
            metrics = self.evaluate_model()
            
            print("🎉 Quick training completed successfully!")
            print(f"📁 Results saved in: {self.results_dir}")
            
            return results, metrics
            
        except Exception as e:
            print(f"❌ Training failed: {e}")
            raise

def main():
    """Main function"""
    print("🔥💨 Quick YOLOv8 Fire & Smoke Detection Training")
    print("=" * 55)
    
    # Quick training setup
    trainer = QuickFireSmokeTrainer(
        data_path="data/data.yaml",
        model_size="yolov8s",           # Good balance of speed and accuracy
        epochs=100,                     # Reasonable number for quick training
        img_size=640                    # Standard input size
    )
    
    # Run training
    results, metrics = trainer.run_quick_training()
    
    print("\n🎊 TRAINING COMPLETED!")
    print("=" * 30)
    print(f"🎯 mAP@0.5: {metrics.box.map50:.4f}")
    print(f"🎯 mAP@0.5:0.95: {metrics.box.map:.4f}")
    print(f"🔍 Precision: {metrics.box.mp:.4f}")
    print(f"🔍 Recall: {metrics.box.mr:.4f}")
    print(f"📁 Results: {trainer.results_dir}")
    
    return trainer, results, metrics

if __name__ == "__main__":
    trainer, results, metrics = main()