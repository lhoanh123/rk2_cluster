import mlflow
import mlflow.sklearn
from sklearn.datasets import load_iris
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score

# Load dữ liệu
data = load_iris()
X = data.data
y = data.target
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

# Khởi tạo experiment trong MLflow
mlflow.set_tracking_uri("http://mlflow.mylab.com:5000")  # Đảm bảo rằng đây là đúng với URL MLflow UI của bạn
mlflow.start_run()

# Huấn luyện mô hình
model = RandomForestClassifier(n_estimators=100)
model.fit(X_train, y_train)

# Dự đoán và tính accuracy
y_pred = model.predict(X_test)
accuracy = accuracy_score(y_test, y_pred)

# Log tham số và metrics vào MLflow
mlflow.log_param("n_estimators", 100)
mlflow.log_metric("accuracy", accuracy)

# Log mô hình học máy vào MLflow
mlflow.sklearn.log_model(model, "random_forest_model")

mlflow.end_run()
