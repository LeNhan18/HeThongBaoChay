from huggingface_hub import login, upload_folder

# (optional) Login with your Hugging Face credentials
login()

# Push your model files
upload_folder(folder_path="E:\\HeThongBaoChay\\training_results_20251125_021040\\advanced_fire_smoke_yolo11s\\weights\\best.pt", repo_id="LeNhan18/YOLOV11FIRESMOKE", repo_type="model")
