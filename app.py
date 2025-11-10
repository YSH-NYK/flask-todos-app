from flask import Flask, request, render_template
from config import Config
from models import db
from routes import todo_bp
from logger import Logger

def create_app():
    app = Flask(__name__)
    config = Config()
    app.config.from_object(config)

    db.init_app(app)

    with app.app_context():
        db.create_all()  # Create tables if not exist

    app.register_blueprint(todo_bp)

    log = Logger().get_logger()
    log.info("Flask Todo App started with SQLite3")

# === Global Error Handlers ===
    @app.errorhandler(404)
    def not_found(error):
        log.warning(f"Global 404: {request.url}")
        return render_template('404.html'), 404

    @app.errorhandler(500)
    def internal_error(error):
        db.session.rollback()
        log.error(f"Global 500: {error} | URL: {request.url}")
        return render_template('500.html'), 500



    return app

if __name__ == '__main__':
    app = create_app()
    app.run(debug=False)