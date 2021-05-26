from flask import Flask, render_template
from . import db

def create_app():
    app = Flask(__name__)

    @app.route("/")
    def index():
        return render_template('index.html', rezepte=db.rezept_liste())

    @app.route('/hello/')
    @app.route('/hello/<name>')
    def hello(name=None):
        return render_template('hello.html', name=name)

    return app
