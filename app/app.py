from flask import Flask, jsonify, render_template, request
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
import time

app = Flask(__name__)

# Prometheus metrics
REQUEST_COUNT = Counter("http_requests_total", "Total HTTP Requests", ['method','endpoint','http_status'])
REQUEST_LATENCY = Histogram("http_request_latency_seconds", "Request latency", ['endpoint'])

@app.route('/')
def index():
    start = time.time()
    resp = render_template('index.html', message="Hello from MVP Test App")
    REQUEST_COUNT.labels(request.method, '/', 200).inc()
    REQUEST_LATENCY.labels('/').observe(time.time() - start)
    return resp

@app.route('/api/hello')
def api_hello():
    start = time.time()
    data = {"message": "hello", "status": "ok"}
    REQUEST_COUNT.labels(request.method, '/api/hello', 200).inc()
    REQUEST_LATENCY.labels('/api/hello').observe(time.time() - start)
    return jsonify(data)

@app.route('/api/error')
def api_error():
    start = time.time()
    REQUEST_COUNT.labels(request.method, '/api/error', 500).inc()
    REQUEST_LATENCY.labels('/api/error').observe(time.time() - start)
    return jsonify({"error": "simulated"}), 500

@app.route('/metrics')
def metrics():
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=8080)
