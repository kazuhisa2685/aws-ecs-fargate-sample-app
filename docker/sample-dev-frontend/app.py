from flask import Flask
app = Flask(__name__)

# このルートパスをALBのhealthcheckのパスに合わせないといけない。
@app.route("/")
def index():
    return "Hello from Docker + ECR2!"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
