from flask import Flask, render_template
from . import db

def create_app():
    app = Flask(__name__)

    @app.route("/")
    @app.route("/rezepte/")
    def index():
        return render_template('index.html', rezepte=db.rezept_liste())

    @app.route('/rezepte/<int:rezept_id>')
    def rezept_details(rezept_id):
        return render_template('rezept_details.html', rezept=db.rezept_details(rezept_id))

    return app
