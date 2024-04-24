# Скрипт запускает nginx 
# чтобы подписать сертификат
#
from flask import Flask, request, jsonify
import os
import subprocess

app = Flask(__name__)

@app.route("/sign_certificate", methods=["POST"])
def sign_certificate():
    # Проверьте авторизацию пользователя
    auth = request.authorization
    if not auth or auth.username != "your_username" or auth.password != "your_password":
        return jsonify({"error": "Unauthorized"}), 401

    # Получите CSR от клиента
    csr = request.form.get("csr")
    if not csr:
        return jsonify({"error": "CSR not provided"}), 400

    # Сохраните CSR во временный файл
    with open("/tmp/client.csr", "w") as f:
        f.write(csr)

    # Подпишите CSR с помощью EasyRSA
    sign_cmd = ["/home/filatof/easy-rsa/easyrsa", "sign-req", "client", "/tmp/client.csr"]
    try:
        subprocess.check_call(sign_cmd)
    except subprocess.CalledProcessError:
        return jsonify({"error": "Failed to sign CSR"}), 500

    # Прочитайте подписанный сертификат и сертификат сервера СА
    signed_cert_path = "/home/filatof/easy-rsa/pki/issued/client.crt"
    ca_cert_path = "/home/filatof/easy-rsa/pki/ca.crt"

    with open(signed_cert_path, "r") as f:
        signed_cert = f.read()

    with open(ca_cert_path, "r") as f:
        ca_cert = f.read()

    # Удалите временный CSR-файл
    os.remove("/tmp/client.csr")

    # Верните ответ с подписанным сертификатом и сертификатом сервера СА
    return jsonify({
        "signed_cert": signed_cert,
        "ca_cert": ca_cert
    })

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)

