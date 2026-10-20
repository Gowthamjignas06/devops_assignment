from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/about', methods=['GET'])
def about():
    return jsonify({
        "name": "Simple REST API",
        "version": "1.0",
        "description": "This is a simple REST API built with Flask."
    })

if __name__ == '__main__':
    # host='0.0.0.0' is required inside a container; the original's default
    # (127.0.0.1) makes -p 5001:5001 unreachable from your machine.
    app.run(host='0.0.0.0', debug=True, port=5001)  # Specify the port number here
