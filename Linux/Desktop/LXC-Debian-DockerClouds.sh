#!/bin/bash
# DockerClouds - Multi-user Containerized Cloud Desktop Platform
# =================================================================
# 此脚本从 DockerClouds 项目(G:\Codes\PikaProjects\DockerClouds)的构建逻辑生成
# 用于在 LXC 桌面容器内安装 DockerClouds Flask Web 管理平台

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Check -----------------------------------------------------------
file="/etc/lxc-de-flag"
if [[ ! -f "$file" ]] || [[ ! -s "$file" ]]; then
    apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Server.sh | bash -e
else
    read -r content < "$file"
    case "$content" in
        0) echo "检查通过，开始安装 DockerClouds 平台....." ;;
        *) echo "DockerClouds 已安装或环境不符合要求" && exit ;;
    esac
fi

# Install Python & Dependencies -----------------------------------
echo "安装 Python 环境和依赖....."
apt update
DEBIAN_FRONTEND=noninteractive apt install -y python3 python3-pip python3-venv python3-dev

# 创建应用目录结构 (对应 DockerClouds 项目结构)
APP_DIR="/opt/dockerclouds"
mkdir -p ${APP_DIR}/{Container,SubModule,Templates/static,instance,uploads}

# 安装 Python 依赖 (来自 DockerClouds/Setups.txt)
cat > ${APP_DIR}/requirements.txt <<'PYREQ'
Flask
Flask-Login
Flask-Migrate
Flask-SQLAlchemy
Flask-WTF
requests
SQLAlchemy
typing_extensions
urllib3
websocket-client
Werkzeug
WTForms
docker
docker-py
PYREQ

pip3 install --break-system-packages -r ${APP_DIR}/requirements.txt || \
pip3 install -r ${APP_DIR}/requirements.txt

# Config.py (对应 DockerClouds/Config.py) --------------------------
cat > ${APP_DIR}/Config.py <<'PYCONFIG'
import os
from datetime import timedelta


class Config:
    # Flask 配置
    SECRET_KEY = os.environ.get('SECRET_KEY') or 'your-secret-key-here'
    SESSION_COOKIE_NAME = 'cloud_desktop_session'
    PERMANENT_SESSION_LIFETIME = timedelta(minutes=30)

    # 数据库配置
    SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL') or 'sqlite:////opt/dockerclouds/instance/site.db'
    SQLALCHEMY_TRACK_MODIFICATIONS = False

    # Docker 配置
    DOCKER_SOCKET = os.environ.get('DOCKER_SOCKET') or 'unix:///var/run/docker.sock'
    CONTAINER_NETWORK = 'cloud-desktop-network'

    # 文件存储目录
    UPLOAD_FOLDER = os.path.join(os.getcwd(), 'uploads')

    # GPU 支持
    GPU_ENABLED = os.environ.get('GPU_ENABLED', False)

    # 默认容器配置
    DEFAULT_CPU_LIMIT = 1.0
    DEFAULT_MEMORY_LIMIT = 1024  # MB
    DEFAULT_DISK_LIMIT = 10  # GB
PYCONFIG

# ConStatus.py (对应 DockerClouds/Container/ConStatus.py) ----------
cat > ${APP_DIR}/Container/__init__.py <<'PYINIT1'
PYINIT1

cat > ${APP_DIR}/Container/ConStatus.py <<'PYCS'
import enum
con_status = {
    "unknown": 9,
    "created": 0,
    "onstart": 1,
    "running": 2,
    "stopped": 3,
    "exited": 3
}


class ConStatus(enum.Enum):
    UNLOADS = 8
    UNKNOWN = 9
    CREATED = 0
    ONSTART = 1
    RUNNING = 2
    STOPPED = 3

    @staticmethod
    def from_text(text: str):
        for key_text in con_status:
            if text == key_text:
                return ConStatus(con_status[key_text])
        return ConStatus.UNKNOWN

    def __str__(self):
        for key_text in con_status:
            if self.value == con_status[key_text]:
                return key_text
        return "unknown"


CS = ConStatus
PYCS

# ObjectAPI.py (对应 DockerClouds/Container/ObjectAPI.py) ----------
cat > ${APP_DIR}/Container/ObjectAPI.py <<'PYOAPI'
from abc import ABC, abstractmethod


class ObjectAPI(ABC):
    # 初始化管理对象 ====================
    @abstractmethod
    def __init__(self, engine: str = ""):
        pass

    # 创建容器 ==========================
    @abstractmethod
    def con_create(self, img_name, tags, container_name):
        pass

    # 启动容器 ==========================
    @abstractmethod
    def con_launch(self, container_uuid):
        pass

    # 重启容器 ==========================
    @abstractmethod
    def con_reboot(self, container_uuid):
        pass

    # 停止容器 ==========================
    @abstractmethod
    def con_paused(self, container_uuid):
        pass

    # 删除容器 ==========================
    @abstractmethod
    def con_delete(self, container_uuid):
        pass

    # 查询容器 ==========================
    @abstractmethod
    def con_prints(self, user_uuid=None):
        pass

    # 容器详情 ==========================
    @abstractmethod
    def con_detail(self, container_uuid):
        pass

    # 镜像下载 ==========================
    @abstractmethod
    def img_pulled(self, img_name, tags):
        pass

    # 镜像上传 ==========================
    @abstractmethod
    def img_pushed(self, img_name, tags):
        pass

    # 镜像删除 ==========================
    @abstractmethod
    def img_delete(self, img_name, tags):
        pass

    # 镜像详情 ==========================
    @abstractmethod
    def img_detail(self, img_name, tags):
        pass

    # 镜像列表 ==========================
    @abstractmethod
    def img_prints(self, img_name, tags):
        pass

    # 镜像构建 ==========================
    @abstractmethod
    def img_builds(self, builder_object):
        pass
PYOAPI

# Container.py (对应 DockerClouds/Container/Container.py) ----------
cat > ${APP_DIR}/Container/Container.py <<'PYCONT'
import json
from Container.ConStatus import CS


class Container:
    def __init__(self,
                 uuid: str = "",
                 name: str = "",
                 temp: str = "",
                 port: dict = None,
                 flag: CS | str = CS.UNKNOWN,
                 ):
        self.uuid = uuid
        self.name = name
        self.temp = temp
        self.port = port
        self.flag = flag
        if type(self.flag) == CS:
            self.flag = CS.from_text(self.flag)

    def json(self):
        return json.dumps(
            {
                "uuid": self.uuid,
                "name": self.name,
                "temp": self.temp,
                "port": self.port,
                "flag": str(self.flag),
            }
        )
PYCONT

# DockerAPI.py (对应 DockerClouds/Container/DockerAPI.py) ----------
cat > ${APP_DIR}/Container/DockerAPI.py <<'PYDAPI'
import docker
from Container import ObjectAPI
from Container import Container as ContainerModel
from Container.ConStatus import CS


class DockerAPI(ObjectAPI.ObjectAPI):
    # 初始化管理对象 ====================
    def __init__(self, engine: str = ""):
        self.client = docker.from_env()
        self.select = []

    # 创建容器 ==========================
    def con_create(self,
                   img_name, tags="latest",
                   container_name=None,
                   auto_remove=False):
        self.client.containers.run(
            image=img_name + ":" + tags,
            name=container_name,
            detach=True,
            remove=auto_remove
        )

    # 加载容器 ==========================
    def con_loader(self, uuid):
        temp_api = self.client.containers
        return temp_api.get(uuid)

    # 启动容器 ==========================
    def con_launch(self, uuid):
        con_data = self.con_loader(uuid)
        con_data.start()

    # 重启容器 ==========================
    def con_reboot(self, uuid):
        con_data = self.con_loader(uuid)
        con_data.restart()

    # 停止容器 ==========================
    def con_paused(self, uuid):
        con_data = self.con_loader(uuid)
        con_data.stop()

    # 删除容器 ==========================
    def con_delete(self, uuid):
        con_data = self.con_loader(uuid)
        con_data.remove()

    # 查询容器 ==========================
    def con_prints(self, user_uuid=None):
        temp_api = self.client.containers
        list_con = temp_api.list(all=True)
        list_out = []
        for item_con in list_con:
            temp_con = ContainerModel.Container(
                uuid=item_con.short_id,
                name=item_con.name,
                temp=item_con.image,
                port=item_con.status,
                flag=CS.from_text(item_con.status),
            )
            list_out.append(temp_con)
        return list_out

    # 容器详情 ==========================
    def con_detail(self, container_uuid):
        pass

    # 镜像下载 ==========================
    def img_pulled(self, img_name, tags):
        pass

    # 镜像上传 ==========================
    def img_pushed(self, img_name, tags):
        pass

    # 镜像删除 ==========================
    def img_delete(self, img_name, tags):
        pass

    # 镜像详情 ==========================
    def img_detail(self, img_name, tags):
        pass

    # 镜像列表 ==========================
    def img_prints(self, img_name, tags):
        pass

    # 镜像构建 ==========================
    def img_builds(self, builder_object):
        pass
PYDAPI

# Object.py (对应 DockerClouds/Container/ObjectAPI.py 中的 Object 实例)
cat > ${APP_DIR}/Container/Object.py <<'PYOBJ'
from Container.DockerAPI import DockerAPI


def Object():
    return DockerAPI()
PYOBJ

# SubModule/__init__.py ---------------------------------------------
cat > ${APP_DIR}/SubModule/__init__.py <<'PYINIT2'
PYINIT2

# SubModule/Models.py (对应 DockerClouds/SubModule/Models.py) -------
cat > ${APP_DIR}/SubModule/Models.py <<'PYMODEL'
from datetime import datetime
from flask_sqlalchemy import SQLAlchemy
from flask_login import UserMixin
from werkzeug.security import generate_password_hash, check_password_hash

db = SQLAlchemy()


class User(UserMixin, db.Model):
    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(128))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    last_login = db.Column(db.DateTime)
    is_admin = db.Column(db.Boolean, default=False)
    containers = db.relationship('Container', backref='user', lazy=True)

    def set_password(self, password):
        self.password_hash = generate_password_hash(password)

    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

    def __repr__(self):
        return f'<User {self.email}>'


class Container(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(64), unique=True, nullable=False)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    image = db.Column(db.String(128), nullable=False)
    desktop_env = db.Column(db.String(32), nullable=False)
    status = db.Column(db.String(32), default='stopped')
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    started_at = db.Column(db.DateTime)
    stopped_at = db.Column(db.DateTime)
    ip_address = db.Column(db.String(15))
    port_mappings = db.relationship('PortMapping', backref='container', lazy=True)
    files = db.relationship('ContainerFile', backref='container', lazy=True)

    def __repr__(self):
        return f'<Container {self.name}>'


class PortMapping(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    container_id = db.Column(db.Integer, db.ForeignKey('container.id'), nullable=False)
    host_port = db.Column(db.Integer, nullable=False)
    container_port = db.Column(db.Integer, nullable=False)
    protocol = db.Column(db.String(10), default='tcp')

    def __repr__(self):
        return f'<PortMapping {self.container_id}: {self.host_port}->{self.container_port}>'


class ContainerFile(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    container_id = db.Column(db.Integer, db.ForeignKey('container.id'), nullable=False)
    filename = db.Column(db.String(256), nullable=False)
    path = db.Column(db.String(256), nullable=False)
    uploaded_at = db.Column(db.DateTime, default=datetime.utcnow)

    def __repr__(self):
        return f'<ContainerFile {self.filename} in {self.container_id}>'


class InvitationCode(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    code = db.Column(db.String(64), unique=True, nullable=False)
    created_by = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    used = db.Column(db.Boolean, default=False)
    expires_at = db.Column(db.DateTime)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def __repr__(self):
        return f'<InvitationCode {self.code}>'
PYMODEL

# SubModule/Submit.py (对应 DockerClouds/SubModule/Submit.py) -------
cat > ${APP_DIR}/SubModule/Submit.py <<'PYSUBMIT'
from flask_wtf import FlaskForm
from wtforms import StringField, PasswordField, BooleanField, SubmitField, SelectField, IntegerField, TextAreaField
from wtforms.validators import DataRequired, Email, EqualTo, Length, Optional, ValidationError
from SubModule.Models import User, InvitationCode


class LoginForm(FlaskForm):
    email = StringField('Email', validators=[DataRequired(), Email()])
    password = PasswordField('Password', validators=[DataRequired()])
    remember_me = BooleanField('Remember Me')
    submit = SubmitField('Sign In')


class RegistrationForm(FlaskForm):
    email = StringField('Email', validators=[DataRequired(), Email()])
    password = PasswordField('Password', validators=[DataRequired(), Length(min=8)])
    password2 = PasswordField(
        'Repeat Password', validators=[DataRequired(), EqualTo('password')])
    invitation_code = StringField('Invitation Code', validators=[DataRequired()])
    submit = SubmitField('Register')

    def validate_email(self, email):
        user = User.query.filter_by(email=email.data).first()
        if user is not None:
            raise ValidationError('Please use a different email address.')

    def validate_invitation_code(self, invitation_code):
        code = InvitationCode.query.filter_by(code=invitation_code.data).first()
        if not code or code.used:
            raise ValidationError('Invalid or expired invitation code.')


class ContainerCreateForm(FlaskForm):
    name = StringField('Container Name', validators=[DataRequired(), Length(max=32)])
    os_type = SelectField('Operating System', choices=[
        ('ubuntu', 'Ubuntu'),
        ('debian', 'Debian'),
        ('fedora', 'Fedora'),
        ('alpine', 'Alpine')
    ], validators=[DataRequired()])
    os_version = SelectField('Version', choices=[], validators=[DataRequired()], coerce=str)
    desktop_env = SelectField('Desktop Environment', choices=[
        ('gnome', 'GNOME'),
        ('kde', 'KDE'),
        ('xfce', 'XFCE'),
        ('lxde', 'LXDE'),
        ('mate', 'MATE')
    ], validators=[DataRequired()])
    cpu_limit = IntegerField('CPU Limit (%)', default=100, validators=[Optional()])
    memory_limit = IntegerField('Memory Limit (MB)', default=1024, validators=[Optional()])
    disk_limit = IntegerField('Disk Limit (GB)', default=10, validators=[Optional()])
    assign_gpu = BooleanField('Assign GPU', default=False)
    gpu_id = SelectField('GPU ID', choices=[], validators=[Optional()], coerce=str)
    ports = TextAreaField('Port Mappings (host:container)', validators=[Optional()])
    files = TextAreaField('Files to Upload', validators=[Optional()])
    software = TextAreaField('Additional Software (one per line)', validators=[Optional()])
    submit = SubmitField('Create Container')


class FileUploadForm(FlaskForm):
    files = TextAreaField('Files to Upload (one per line)', validators=[DataRequired()])
    container_id = SelectField('Select Container', choices=[], coerce=int, validators=[DataRequired()])
    submit = SubmitField('Upload Files')


class PasswordChangeForm(FlaskForm):
    current_password = PasswordField('Current Password', validators=[DataRequired()])
    new_password = PasswordField('New Password', validators=[DataRequired(), Length(min=8)])
    new_password2 = PasswordField(
        'Repeat New Password', validators=[DataRequired(), EqualTo('new_password')])
    submit = SubmitField('Change Password')
PYSUBMIT

# Server.py (对应 DockerClouds/Server.py) ---------------------------
cat > ${APP_DIR}/Server.py <<'PYSERVER'
from flask import Flask, render_template, redirect, url_for, flash, jsonify
from flask_login import LoginManager, current_user, login_user, logout_user, login_required
from flask_migrate import Migrate
from SubModule.Models import db, User, Container, ContainerFile, InvitationCode
from SubModule.Submit import LoginForm, RegistrationForm, ContainerCreateForm, FileUploadForm, PasswordChangeForm
from Container.Object import Object
import os
from datetime import datetime

# 初始化应用
app = Flask(__name__)
app.config.from_object('Config.Config')

# 初始化扩展
db.init_app(app)
migrate = Migrate(app, db)
login_manager = LoginManager(app)
login_manager.login_view = 'login'

# 初始化Docker管理器
docker_manager = Object()


# 用户加载器
@login_manager.user_loader
def load_user(id):
    return User.query.get(int(id))


# 路由和视图函数

@app.route('/')
def index():
    return render_template('index.html')


@app.route('/login', methods=['GET', 'POST'])
def login():
    if current_user.is_authenticated:
        return redirect(url_for('dashboard'))

    form = LoginForm()
    if form.validate_on_submit():
        user = User.query.filter_by(email=form.email.data).first()
        if user and user.check_password(form.password.data):
            login_user(user, remember=form.remember_me.data)
            user.last_login = datetime.utcnow()
            db.session.commit()
            return redirect(url_for('dashboard'))
        flash('Invalid username or password')
    return render_template('login.html', form=form)


@app.route('/register', methods=['GET', 'POST'])
def register():
    if current_user.is_authenticated:
        return redirect(url_for('dashboard'))

    form = RegistrationForm()
    if form.validate_on_submit():
        user = User(email=form.email.data)
        user.set_password(form.password.data)
        db.session.add(user)

        # 使用邀请码
        code = InvitationCode.query.filter_by(code=form.invitation_code.data).first()
        if code:
            code.used = True
            db.session.add(code)

        db.session.commit()
        flash('Congratulations, you are now a registered user!')
        return redirect(url_for('login'))
    return render_template('register.html', form=form)


@app.route('/logout')
def logout():
    logout_user()
    return redirect(url_for('index'))


@app.route('/dashboard')
@login_required
def dashboard():
    containers = Container.query.filter_by(user_id=current_user.id).all()
    return render_template('dashboard.html', containers=containers)


@app.route('/containers')
@login_required
def containers():
    containers = Container.query.filter_by(user_id=current_user.id).all()
    return render_template('containers.html', containers=containers)


@app.route('/create-container', methods=['GET', 'POST'])
@login_required
def create_container():
    form = ContainerCreateForm()

    # 动态设置操作系统版本选项
    os_types = [('ubuntu', 'Ubuntu'), ('debian', 'Debian'),
                ('fedora', 'Fedora'), ('alpine', 'Alpine')]
    form.os_type.choices = os_types

    if form.validate_on_submit():
        flash('Container created successfully!')
        return redirect(url_for('containers'))

    return render_template('create_container.html', form=form)


@app.route('/container/<int:container_id>')
@login_required
def container_detail(container_id):
    container = Container.query.get_or_404(container_id)
    if container.user_id != current_user.id and not current_user.is_admin:
        return redirect(url_for('containers'))
    return render_template('container_detail.html', container=container)


@app.route('/start-container/<int:container_id>', methods=['POST'])
@login_required
def start_container(container_id):
    container = Container.query.get_or_404(container_id)
    if container.user_id != current_user.id and not current_user.is_admin:
        return jsonify({'success': False, 'message': 'Permission denied'}), 403

    container.status = 'running'
    container.started_at = datetime.utcnow()
    db.session.commit()
    return jsonify({'success': True, 'message': 'Container started successfully'})


@app.route('/stop-container/<int:container_id>', methods=['POST'])
@login_required
def stop_container(container_id):
    container = Container.query.get_or_404(container_id)
    if container.user_id != current_user.id and not current_user.is_admin:
        return jsonify({'success': False, 'message': 'Permission denied'}), 403

    container.status = 'stopped'
    container.stopped_at = datetime.utcnow()
    db.session.commit()
    return jsonify({'success': True, 'message': 'Container stopped successfully'})


@app.route('/restart-container/<int:container_id>', methods=['POST'])
@login_required
def restart_container(container_id):
    container = Container.query.get_or_404(container_id)
    if container.user_id != current_user.id and not current_user.is_admin:
        return jsonify({'success': False, 'message': 'Permission denied'}), 403

    container.status = 'running'
    container.started_at = datetime.utcnow()
    db.session.commit()
    return jsonify({'success': True, 'message': 'Container restarted successfully'})


@app.route('/delete-container/<int:container_id>', methods=['POST'])
@login_required
def delete_container(container_id):
    container = Container.query.get_or_404(container_id)
    if container.user_id != current_user.id and not current_user.is_admin:
        return jsonify({'success': False, 'message': 'Permission denied'}), 403

    db.session.delete(container)
    db.session.commit()
    return jsonify({'success': True, 'message': 'Container deleted successfully'})


@app.route('/files')
@login_required
def files():
    files = ContainerFile.query.filter_by(user_id=current_user.id).all()
    form = FileUploadForm()
    form.container_id.choices = [(c.id, c.name) for c in Container.query.filter_by(user_id=current_user.id).all()]
    return render_template('files.html', files=files, form=form)


@app.route('/upload-files', methods=['POST'])
@login_required
def upload_files():
    form = FileUploadForm()
    form.container_id.choices = [(c.id, c.name) for c in Container.query.filter_by(user_id=current_user.id).all()]

    if form.validate_on_submit():
        container_id = form.container_id.data
        container = Container.query.get_or_404(container_id)

        if container.user_id != current_user.id and not current_user.is_admin:
            return jsonify({'success': False, 'message': 'Permission denied'}), 403

        files_to_upload = form.files.data.splitlines()
        for file_info in files_to_upload:
            if ':' in file_info:
                file_path, container_path = file_info.split(':', 1)
                filename = os.path.basename(file_path)
                db_file = ContainerFile(
                    filename=filename,
                    path=container_path,
                    user_id=current_user.id,
                    container_id=container_id
                )
                db.session.add(db_file)

        db.session.commit()
        flash('Files uploaded successfully!')
        return redirect(url_for('files'))

    return render_template('files.html', files=[], form=form)


@app.route('/download-file/<int:file_id>')
@login_required
def download_file(file_id):
    file = ContainerFile.query.get_or_404(file_id)
    if file.user_id != current_user.id and not current_user.is_admin:
        return redirect(url_for('files'))
    return f"Would download {file.filename} from {file.path}"


@app.route('/delete-file/<int:file_id>', methods=['POST'])
@login_required
def delete_file(file_id):
    file = ContainerFile.query.get_or_404(file_id)
    if file.user_id != current_user.id and not current_user.is_admin:
        return jsonify({'success': False, 'message': 'Permission denied'}), 403

    db.session.delete(file)
    db.session.commit()
    return jsonify({'success': True, 'message': 'File deleted successfully'})


@app.route('/change-password', methods=['GET', 'POST'])
@login_required
def change_password():
    form = PasswordChangeForm()
    if form.validate_on_submit():
        if current_user.check_password(form.current_password.data):
            current_user.set_password(form.new_password.data)
            db.session.commit()
            flash('Your password has been updated.')
            return redirect(url_for('dashboard'))
        else:
            flash('Current password is incorrect.')
    return render_template('change_password.html', form=form)


@app.before_request
def create_tables():
    db.create_all()


@app.context_processor
def inject_globals():
    """将一些全局变量注入模板"""
    return {
        'current_year': datetime.utcnow().year,
        'user': current_user
    }


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
PYSERVER

# 创建基础 HTML 模板 (最小化后端模板，配合 DockerClouds/Frontends 前端) --
cat > ${APP_DIR}/Templates/index.html <<'HTMINDEX'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DockerClouds - Cloud Desktop Platform</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0f172a; color: #e2e8f0; min-height: 100vh; display: flex; align-items: center; justify-content: center; }
        .container { text-align: center; padding: 2rem; }
        h1 { font-size: 2.5rem; margin-bottom: 1rem; background: linear-gradient(135deg, #6366f1, #8b5cf6); -webkit-background-clip: text; -webkit-text-fill-color: transparent; }
        p { color: #94a3b8; margin-bottom: 2rem; }
        .btn { display: inline-block; padding: 0.75rem 2rem; margin: 0.5rem; border-radius: 8px; text-decoration: none; font-weight: 600; transition: all 0.3s; }
        .btn-primary { background: #6366f1; color: white; }
        .btn-primary:hover { background: #4f46e5; transform: translateY(-2px); }
        .btn-secondary { background: #1e293b; color: #e2e8f0; border: 1px solid #334155; }
        .btn-secondary:hover { background: #334155; }
    </style>
</head>
<body>
    <div class="container">
        <h1>DockerClouds</h1>
        <p>Multi-user Containerized Cloud Desktop Platform</p>
        <div>
            <a href="/login" class="btn btn-primary">登录</a>
            <a href="/register" class="btn btn-secondary">注册</a>
        </div>
    </div>
</body>
</html>
HTMINDEX

cat > ${APP_DIR}/Templates/login.html <<'HTMLOGIN'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>登录 - DockerClouds</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0f172a; color: #e2e8f0; min-height: 100vh; display: flex; align-items: center; justify-content: center; }
        .card { background: #1e293b; padding: 2.5rem; border-radius: 16px; width: 100%; max-width: 400px; box-shadow: 0 25px 50px -12px rgba(0,0,0,0.5); }
        h1 { text-align: center; margin-bottom: 2rem; color: #6366f1; }
        label { display: block; margin-bottom: 0.5rem; color: #94a3b8; font-size: 0.875rem; }
        input[type="email"], input[type="password"] { width: 100%; padding: 0.75rem; background: #0f172a; border: 1px solid #334155; border-radius: 8px; color: #e2e8f0; margin-bottom: 1rem; font-size: 1rem; }
        input[type="email"]:focus, input[type="password"]:focus { outline: none; border-color: #6366f1; }
        input[type="submit"] { width: 100%; padding: 0.75rem; background: #6366f1; color: white; border: none; border-radius: 8px; font-size: 1rem; font-weight: 600; cursor: pointer; transition: background 0.3s; }
        input[type="submit"]:hover { background: #4f46e5; }
        .links { text-align: center; margin-top: 1rem; }
        .links a { color: #6366f1; text-decoration: none; margin: 0 0.5rem; }
        .flash { background: #7f1d1d; color: #fca5a5; padding: 0.75rem; border-radius: 8px; margin-bottom: 1rem; }
    </style>
</head>
<body>
    <div class="card">
        <h1>登录</h1>
        {% with messages = get_flashed_messages() %}
        {% if messages %}<div class="flash">{{ messages[0] }}</div>{% endif %}
        {% endwith %}
        <form method="POST">
            {{ form.hidden_tag() }}
            <label>邮箱</label>
            {{ form.email() }}
            <label>密码</label>
            {{ form.password() }}
            {{ form.submit() }}
        </form>
        <div class="links">
            <a href="/">首页</a>
            <a href="/register">注册</a>
        </div>
    </div>
</body>
</html>
HTMLOGIN

cat > ${APP_DIR}/Templates/register.html <<'HTMREG'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>注册 - DockerClouds</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0f172a; color: #e2e8f0; min-height: 100vh; display: flex; align-items: center; justify-content: center; }
        .card { background: #1e293b; padding: 2.5rem; border-radius: 16px; width: 100%; max-width: 400px; box-shadow: 0 25px 50px -12px rgba(0,0,0,0.5); }
        h1 { text-align: center; margin-bottom: 2rem; color: #8b5cf6; }
        label { display: block; margin-bottom: 0.5rem; color: #94a3b8; font-size: 0.875rem; }
        input { width: 100%; padding: 0.75rem; background: #0f172a; border: 1px solid #334155; border-radius: 8px; color: #e2e8f0; margin-bottom: 1rem; font-size: 1rem; }
        input:focus { outline: none; border-color: #8b5cf6; }
        input[type="submit"] { width: 100%; padding: 0.75rem; background: #8b5cf6; color: white; border: none; border-radius: 8px; font-size: 1rem; font-weight: 600; cursor: pointer; }
        input[type="submit"]:hover { background: #7c3aed; }
        .links { text-align: center; margin-top: 1rem; }
        .links a { color: #8b5cf6; text-decoration: none; margin: 0 0.5rem; }
        .flash { background: #7f1d1d; color: #fca5a5; padding: 0.75rem; border-radius: 8px; margin-bottom: 1rem; }
    </style>
</head>
<body>
    <div class="card">
        <h1>注册</h1>
        {% with messages = get_flashed_messages() %}
        {% if messages %}<div class="flash">{{ messages[0] }}</div>{% endif %}
        {% endwith %}
        <form method="POST">
            {{ form.hidden_tag() }}
            <label>邮箱</label>
            {{ form.email() }}
            <label>密码</label>
            {{ form.password() }}
            <label>确认密码</label>
            {{ form.password2() }}
            <label>邀请码</label>
            {{ form.invitation_code() }}
            {{ form.submit() }}
        </form>
        <div class="links">
            <a href="/">首页</a>
            <a href="/login">登录</a>
        </div>
    </div>
</body>
</html>
HTMREG

cat > ${APP_DIR}/Templates/dashboard.html <<'HTMLDASH'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>仪表盘 - DockerClouds</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0f172a; color: #e2e8f0; min-height: 100vh; }
        nav { background: #1e293b; padding: 1rem 2rem; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #334155; }
        nav h2 { color: #6366f1; }
        nav a { color: #94a3b8; text-decoration: none; margin-left: 1.5rem; }
        nav a:hover { color: #e2e8f0; }
        .content { max-width: 1200px; margin: 2rem auto; padding: 0 2rem; }
        h1 { margin-bottom: 2rem; }
        .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 1.5rem; }
        .card { background: #1e293b; padding: 1.5rem; border-radius: 12px; border: 1px solid #334155; }
        .card h3 { margin-bottom: 0.5rem; color: #6366f1; }
        .card p { color: #94a3b8; font-size: 0.875rem; margin-bottom: 0.25rem; }
    </style>
</head>
<body>
    <nav>
        <h2>DockerClouds</h2>
        <div>
            <a href="/dashboard">仪表盘</a>
            <a href="/containers">容器</a>
            <a href="/files">文件</a>
            <a href="/change-password">修改密码</a>
            <a href="/logout">退出</a>
        </div>
    </nav>
    <div class="content">
        <h1>仪表盘</h1>
        <div class="grid">
            {% for container in containers %}
            <div class="card">
                <h3>{{ container.name }}</h3>
                <p>镜像: {{ container.image }}</p>
                <p>桌面: {{ container.desktop_env }}</p>
                <p>状态: {{ container.status }}</p>
            </div>
            {% endfor %}
            {% if not containers %}
            <div class="card">
                <h3>暂无容器</h3>
                <p><a href="/create-container" style="color:#6366f1;">创建第一个容器</a></p>
            </div>
            {% endif %}
        </div>
    </div>
</body>
</html>
HTMLDASH

# 其他模板页面的占位符
for tmpl in containers.html create_container.html container_detail.html files.html change_password.html; do
    cat > ${APP_DIR}/Templates/${tmpl} <<HTMTMPL
{% extends "dashboard.html" %}
{% block content %}<p>Page: ${tmpl}</p>{% endblock %}
HTMTMPL
done

# 设置权限
chown -R user:user ${APP_DIR} 2>/dev/null || true
chmod -R 755 ${APP_DIR}

# Systemd Service ---------------------------------------------------
cat > /etc/systemd/system/dockerclouds.service <<'SYSDUNIT'
[Unit]
Description=DockerClouds Web Management Platform
After=network.target docker.service
Wants=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/dockerclouds
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Environment="FLASK_ENV=production"
Environment="SECRET_KEY=DockerClouds-Production-Secret-Key-2024"
ExecStart=/usr/bin/python3 /opt/dockerclouds/Server.py
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SYSDUNIT

systemctl daemon-reload
systemctl enable dockerclouds.service

# 启动信息写入 run.sh
cat >> /run.sh <<'DCRUN'
echo 'Starting DockerClouds Platform ---------'
systemctl start dockerclouds 2>/dev/null || \
/usr/bin/python3 /opt/dockerclouds/Server.py &
DCRUN

echo "DockerClouds 平台安装完成"
echo "访问地址: http://<container-ip>:5000"
