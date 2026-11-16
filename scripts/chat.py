#!/usr/bin/env python3
"""PyQt6 chat GUI for Ollama with RGBA transparency, Nerd Font icons,
manual model management (install/delete), live status, GPU-offload
reporting, and adjustable context length.

Theming: reads matugen colors (see matugen-chat-template.json), falls back
to pywal, then to built-in defaults.

Readability: every message is its own block (prompt box vs. accent-barred
reply), code blocks get their own panel, and when a reply finishes the view
jumps to the START of the reply instead of the bottom. Alt+Up / Alt+Down
jump between prompts and replies.

Streaming is flicker-free: tokens are buffered and appended to the end of
the document in small batches. The full render only happens once the reply
is finished.

NOTE (Arch): the plain `ollama` package is CPU-only. For an AMD dGPU you
need `ollama-rocm`; for iGPUs use `ollama-vulkan`.
"""

import getpass
import grp
import html as htmllib
import json
import os
import pwd
import re
import subprocess
import shutil
import sys
import time
import urllib.request
from pathlib import Path

from PyQt6.QtCore import Qt, QThread, QTimer, pyqtSignal
from PyQt6.QtGui import (
    QFont, QKeySequence, QShortcut, QTextCharFormat, QTextCursor, QTextDocument,
)
from PyQt6.QtWidgets import (
    QApplication, QCheckBox, QComboBox, QHBoxLayout, QLabel, QPlainTextEdit,
    QPushButton, QTextBrowser, QVBoxLayout, QWidget,
)

HOST = "http://localhost:11434"
FONT = "Hack Nerd Font"

# Where matugen writes the colors (see matugen-chat-template.json).
MATUGEN_PATHS = [
    Path.home() / ".cache/matugen/chat-colors.json",
    Path.home() / ".cache/matugen/colors.json",
]

# How long the model stays loaded in VRAM after the last request.
KEEP_ALIVE = "30m"

# How often buffered tokens are flushed to the view (milliseconds).
FLUSH_MS = 40

MODEL_TIERS = {
    "desktop": [
        ("󰅱 Qwen2.5-Coder (7B) — Blazing fast code gen & daily scripting (~6GB VRAM)", "qwen2.5-coder:7b"),
        ("󰚩 DeepSeek-R1 (8B) — Step-by-step logic & advanced debugging (~8GB VRAM)", "deepseek-r1:8b"),
        ("󰭹 Llama 3.1 (8B) — Elite all-rounder for general chat & questions (~8GB VRAM)", "llama3.1:8b"),
        ("󰊠 Qwen3 (14B) — Balanced reasoning + speed, fits 16GB comfortably (~10GB VRAM)", "qwen3:14b"),
        ("󰓅 Qwen2.5-Coder (14B) — Deep script architecture & complex logic (~11GB VRAM, near 16GB ceiling)", "qwen2.5-coder:14b"),
    ],
    "lite": [
        ("󰊠 Gemma 2 (2B) — Lightest option, fastest replies on CPU or weak iGPU (~2GB)", "gemma2:2b"),
        ("󰅱 Qwen2.5-Coder (3B) — Small but capable for quick scripting help (~3GB)", "qwen2.5-coder:3b"),
        ("󰭹 Llama 3.2 (3B) — Solid general-purpose chat at laptop-friendly size (~3GB)", "llama3.2:3b"),
        ("󰚩 Qwen2.5 (3B) — Balanced reasoning for its size (~3GB)", "qwen2.5:3b"),
    ],
}
DEFAULT_TIER = "desktop"

CTX_OPTIONS = [4096, 8192, 16384, 32768]
DEFAULT_CTX = 8192


def find_binary(name, extra_paths=()):
    found = shutil.which(name)
    if found:
        return found
    for p in extra_paths:
        if Path(p).is_file():
            return str(p)
    return None


def find_ollama():
    """Locate the ollama binary across standard system and user paths."""
    return find_binary("ollama", [
        "/usr/bin/ollama",
        "/usr/local/bin/ollama",
        Path.home() / ".local/bin/ollama",
        "/opt/ollama/ollama",
    ])


def find_rocminfo():
    return find_binary("rocminfo", ["/opt/rocm/bin/rocminfo", "/usr/bin/rocminfo"])


def find_vulkaninfo():
    return find_binary("vulkaninfo", ["/usr/bin/vulkaninfo"])


def pacman_has(pkg):
    """Whether a pacman package is installed."""
    try:
        return subprocess.run(["pacman", "-Qq", pkg], capture_output=True,
                              timeout=10).returncode == 0
    except Exception:
        return False


def ollama_has_gpu_build():
    """The stock `ollama` package on Arch is CPU-only. GPU inference needs
    ollama-rocm (AMD dGPU) or ollama-vulkan (iGPU / other)."""
    return pacman_has("ollama-rocm") or pacman_has("ollama-vulkan") \
        or pacman_has("ollama-cuda")


def user_in_group_db(user, group_name):
    try:
        g = grp.getgrnam(group_name)
        if user in g.gr_mem:
            return True
        return pwd.getpwnam(user).pw_gid == g.gr_gid
    except KeyError:
        return False


def user_in_session_groups(group_name):
    try:
        gid = grp.getgrnam(group_name).gr_gid
        return gid in os.getgroups()
    except KeyError:
        return False


# ---------- colors ----------

def load_colors():
    """Matugen first, then pywal, then built-in defaults.

    Keys: bg, fg, accent (bars/headings), dim (borders), surface (prompt
    box), user (prompt label), code (code panel), error.
    """
    c = dict(bg="#1e1e2e", fg="#cdd6f4", accent="#89b4fa", dim="#6c7086",
             surface="#313244", user="#cba6f7", code="#11111b", error="#f38ba8")

    # matugen: accepts the flat template or the nested {"colors":{"dark":{}}}
    for p in MATUGEN_PATHS:
        try:
            d = json.loads(p.read_text())
            s = d.get("colors", {}).get("dark") or d.get("colors") or d

            def g(*keys, default):
                for k in keys:
                    v = s.get(k)
                    if isinstance(v, dict):
                        v = v.get("hex") or v.get("default", {}).get("hex")
                    if isinstance(v, str) and v.startswith("#"):
                        return v
                return default

            c.update(
                bg=g("surface", "background", default=c["bg"]),
                fg=g("on_surface", default=c["fg"]),
                accent=g("primary", default=c["accent"]),
                dim=g("outline", default=c["dim"]),
                surface=g("surface_container", "surface_variant", default=c["surface"]),
                user=g("secondary", "tertiary", default=c["user"]),
                code=g("surface_container_lowest", "surface_dim", default=c["code"]),
                error=g("error", default=c["error"]),
            )
            return c
        except Exception:
            continue

    # pywal fallback
    try:
        w = json.loads((Path.home() / ".cache/wal/colors.json").read_text())
        bg = w["special"]["background"]
        if bg.strip() == "#000000":
            bg = "#181825"
        c.update(bg=bg, fg=w["special"]["foreground"],
                 accent=w["colors"]["color4"], dim=w["colors"]["color8"],
                 user=w["colors"]["color5"], error=w["colors"]["color1"])
    except Exception:
        pass
    return c


def hex_to_rgba(hex_str, alpha=0.82):
    """Convert a hex color to an RGBA string for transparent windows."""
    hex_str = hex_str.lstrip('#')
    if len(hex_str) != 6:
        return f"rgba(30, 30, 46, {alpha})"
    r = int(hex_str[0:2], 16)
    g = int(hex_str[2:4], 16)
    b = int(hex_str[4:6], 16)
    return f"rgba({r}, {g}, {b}, {alpha})"


def style(c):
    bg_rgba = hex_to_rgba(c["bg"], 0.82)
    surf_rgba = hex_to_rgba(c["bg"], 0.55)
    input_bg = hex_to_rgba(c["bg"], 0.35)
    return f"""
    QWidget {{
        background: {bg_rgba};
        color: {c['fg']};
    }}
    QTextBrowser {{
        background: {surf_rgba};
        border: 1px solid {c['dim']};
        border-radius: 12px;
        padding: 14px;
        selection-background-color: {c['accent']};
        selection-color: {c['bg']};
    }}
    QPlainTextEdit {{
        background: {input_bg};
        border: 1px solid {c['dim']};
        border-top-left-radius: 12px;
        border-bottom-left-radius: 12px;
        border-top-right-radius: 0px;
        border-bottom-right-radius: 0px;
        padding: 10px;
        selection-background-color: {c['accent']};
        selection-color: {c['bg']};
    }}
    QPlainTextEdit:focus {{
        border-color: {c['accent']};
    }}
    QPushButton#send_btn {{
        background: {surf_rgba};
        border: 1px solid {c['dim']};
        border-left: none;
        border-top-right-radius: 12px;
        border-bottom-right-radius: 12px;
        border-top-left-radius: 0px;
        border-bottom-left-radius: 0px;
        padding: 0px 20px;
        font-weight: 600;
    }}
    QPushButton#send_btn:hover {{
        border-color: {c['accent']};
        color: {c['accent']};
    }}
    QComboBox, QPushButton {{
        background: {surf_rgba};
        border: 1px solid {c['dim']};
        border-radius: 10px;
        padding: 6px 14px;
        font-weight: 600;
    }}
    QComboBox:hover, QPushButton:hover {{
        border-color: {c['accent']};
    }}
    QComboBox QAbstractItemView {{
        background: {c['bg']};
        selection-background-color: {c['accent']};
        selection-color: {c['bg']};
        border: 1px solid {c['dim']};
    }}
    QCheckBox {{
        background: transparent;
        spacing: 8px;
        font-weight: 600;
    }}
    QLabel {{
        background: transparent;
        color: {c['dim']};
        font-weight: 600;
    }}
    QLabel#gpu_lbl {{
        color: {c['accent']};
    }}
    QScrollBar:vertical {{
        width: 8px;
        background: transparent;
    }}
    QScrollBar::handle:vertical {{
        background: {c['dim']};
        border-radius: 4px;
        min-height: 24px;
    }}
    QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical {{
        height: 0;
    }}
    """


# ---------- rendering helpers ----------

FENCE = re.compile(r"```([^\n`]*)\n(.*?)(?:```|\Z)", re.S)


def md_chunk_to_html(md):
    """Render a markdown fragment to an HTML body fragment via Qt."""
    doc = QTextDocument()
    doc.setMarkdown(md)
    m = re.search(r"<body[^>]*>(.*)</body>", doc.toHtml(), re.S)
    return m.group(1) if m else htmllib.escape(md)


def md_to_html(md, c):
    """Markdown to HTML. Fenced code blocks get their own tinted panel;
    everything else goes through Qt's markdown parser."""
    out, pos = [], 0
    for m in FENCE.finditer(md):
        if m.start() > pos:
            out.append(md_chunk_to_html(md[pos:m.start()]))
        lang = htmllib.escape(m.group(1).strip())
        code = htmllib.escape(m.group(2).rstrip("\n"))
        label = (f'<span style="color:{c["dim"]}">{lang}</span><br>' if lang else "")
        out.append(
            f'<table width="100%" cellspacing="0" cellpadding="10"><tr>'
            f'<td bgcolor="{c["code"]}">{label}'
            f'<pre style="margin:0; font-family:\'{FONT}\'; color:{c["fg"]}">{code}</pre>'
            f'</td></tr></table>'
        )
        pos = m.end()
    if pos < len(md):
        out.append(md_chunk_to_html(md[pos:]))
    return "".join(out)


_ollama_proc = None


class Stream(QThread):
    chunk = pyqtSignal(str, str)
    failed = pyqtSignal(str)

    def __init__(self, model, messages, think, num_ctx):
        super().__init__()
        self.model, self.messages, self.think = model, messages, think
        self.num_ctx = num_ctx
        self._halt = False

    def halt(self):
        self._halt = True

    def run(self):
        body = json.dumps({
            "model": self.model,
            "messages": self.messages,
            "stream": True,
            "think": self.think,
            "keep_alive": KEEP_ALIVE,
            "options": {"num_ctx": self.num_ctx},
        }).encode()
        req = urllib.request.Request(
            f"{HOST}/api/chat", body, {"Content-Type": "application/json"}
        )
        try:
            with urllib.request.urlopen(req, timeout=300) as r:
                for line in r:
                    if self._halt:
                        break
                    if not line.strip():
                        continue
                    try:
                        d = json.loads(line)
                    except json.JSONDecodeError:
                        # A partial/malformed line shouldn't kill the whole
                        # stream — skip it and keep reading.
                        continue
                    if "error" in d:
                        self.failed.emit(d["error"])
                        return
                    m = d.get("message", {})
                    if m.get("thinking"):
                        self.chunk.emit("think", m["thinking"])
                    if m.get("content"):
                        self.chunk.emit("text", m["content"])
                    if d.get("done"):
                        break
        except Exception as e:
            self.failed.emit(str(e))


class PullThread(QThread):
    progress = pyqtSignal(str)
    finished = pyqtSignal(bool, str)

    def __init__(self, model):
        super().__init__()
        self.model = model

    def run(self):
        body = json.dumps({"name": self.model, "stream": True}).encode()
        req = urllib.request.Request(
            f"{HOST}/api/pull", body, {"Content-Type": "application/json"}
        )
        try:
            with urllib.request.urlopen(req, timeout=1800) as r:
                for line in r:
                    if not line.strip():
                        continue
                    try:
                        d = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    status = d.get("status", "")
                    completed = d.get("completed")
                    total = d.get("total")
                    if completed and total:
                        pct = int((completed / total) * 100)
                        self.progress.emit(f"Installing {self.model}: {status} ({pct}%)")
                    else:
                        self.progress.emit(f"Installing {self.model}: {status}")
            self.finished.emit(True, "")
        except Exception as e:
            self.finished.emit(False, str(e))


class DeleteThread(QThread):
    finished = pyqtSignal(bool, str)

    def __init__(self, model):
        super().__init__()
        self.model = model

    def run(self):
        try:
            req = urllib.request.Request(
                f"{HOST}/api/delete",
                data=json.dumps({"name": self.model}).encode(),
                headers={"Content-Type": "application/json"},
                method="DELETE"
            )
            with urllib.request.urlopen(req, timeout=30) as r:
                self.finished.emit(True, "")
        except Exception as e:
            self.finished.emit(False, str(e))


class PacmanThread(QThread):
    """Runs a privileged shell command via pkexec. `--ask=4` auto-answers
    'yes' to package-conflict prompts, so swapping `ollama` for
    `ollama-rocm` works under --noconfirm."""
    finished = pyqtSignal(bool, str)

    def __init__(self, cmd, timeout=900):
        super().__init__()
        self.cmd = cmd
        self.timeout = timeout

    def run(self):
        try:
            res = subprocess.run(
                ["pkexec", "bash", "-c", self.cmd],
                capture_output=True, text=True, timeout=self.timeout
            )
            if res.returncode == 0:
                self.finished.emit(True, "")
            else:
                self.finished.emit(False, res.stderr.strip() or "Command failed.")
        except Exception as e:
            self.finished.emit(False, str(e))


class BackendCheckThread(QThread):
    """Detects which GPU acceleration path is usable: ROCm, Vulkan, or CPU.
    Also reports whether Ollama itself is a GPU-capable build."""
    result = pyqtSignal(dict)

    def run(self):
        info = {
            "rocm_installed": False, "rocm_gfx": [],
            "rocm_db_groups_ok": False, "rocm_session_groups_ok": False,
            "vulkan_installed": False, "vulkan_devices": [],
            "is_integrated": False,
            "ollama_gpu_build": ollama_has_gpu_build(),
            "backend": "cpu",  # "rocm" | "vulkan" | "cpu"
        }

        rocminfo_bin = find_rocminfo()
        if rocminfo_bin:
            info["rocm_installed"] = True
            try:
                res = subprocess.run([rocminfo_bin], capture_output=True,
                                     text=True, timeout=15)
                info["rocm_gfx"] = sorted(set(re.findall(r"gfx[0-9a-fA-F]+", res.stdout)))
            except Exception:
                pass
            user = getpass.getuser()
            info["rocm_db_groups_ok"] = (user_in_group_db(user, "render")
                                         and user_in_group_db(user, "video"))
            info["rocm_session_groups_ok"] = (user_in_session_groups("render")
                                              and user_in_session_groups("video"))

        vulkaninfo_bin = find_vulkaninfo()
        if vulkaninfo_bin:
            info["vulkan_installed"] = True
            try:
                res = subprocess.run([vulkaninfo_bin, "--summary"],
                                     capture_output=True, text=True, timeout=15)
                out = res.stdout
                info["vulkan_devices"] = [d.strip() for d in
                                          re.findall(r"deviceName\s*=\s*(.+)", out)]
                info["is_integrated"] = bool(
                    re.search(r"PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU", out))
            except Exception:
                pass

        rocm_ready = (info["rocm_installed"] and info["rocm_gfx"]
                      and info["rocm_db_groups_ok"] and info["rocm_session_groups_ok"])
        if rocm_ready:
            info["backend"] = "rocm"
        elif info["vulkan_installed"] and info["vulkan_devices"]:
            info["backend"] = "vulkan"

        self.result.emit(info)


class ServerInitThread(QThread):
    ready = pyqtSignal(str)

    def run(self):
        try:
            with urllib.request.urlopen(f"{HOST}/api/tags", timeout=1) as r:
                self.ready.emit("")
                return
        except Exception:
            pass

        ollama_bin = find_ollama()
        if not ollama_bin:
            self.ready.emit("Ollama binary missing.")
            return

        try:
            global _ollama_proc
            log_path = Path("/tmp/ollama_gui_serve.log")
            env = dict(os.environ)
            # Flash attention + quantized KV cache: faster and lighter on
            # VRAM, which lets bigger contexts stay fully on the GPU.
            env.setdefault("OLLAMA_FLASH_ATTENTION", "1")
            env.setdefault("OLLAMA_KV_CACHE_TYPE", "q8_0")
            with open(log_path, "w") as log_file:
                _ollama_proc = subprocess.Popen(
                    [ollama_bin, "serve"],
                    stdout=log_file,
                    stderr=log_file,
                    env=env,
                )

            for _ in range(30):
                time.sleep(0.3)
                if _ollama_proc.poll() is not None:
                    error_msg = log_path.read_text().strip() or "Process exited unexpectedly."
                    self.ready.emit(f"Ollama crashed on start: {error_msg}")
                    return
                try:
                    with urllib.request.urlopen(f"{HOST}/api/tags", timeout=1) as r:
                        self.ready.emit("")
                        return
                except Exception:
                    pass

            self.ready.emit("Timed out waiting for ollama serve.")
        except Exception as e:
            self.ready.emit(str(e))


class GpuCheckThread(QThread):
    """Reports how much of the running model sits in VRAM (via /api/ps).
    Well under 100% usually means CPU fallback."""
    result = pyqtSignal(str)

    def __init__(self, model):
        super().__init__()
        self.model = model

    def run(self):
        try:
            with urllib.request.urlopen(f"{HOST}/api/ps", timeout=3) as r:
                data = json.load(r)
        except Exception:
            self.result.emit("")
            return

        for m in data.get("models", []):
            if m.get("name") == self.model or m.get("model") == self.model:
                size = m.get("size", 0)
                size_vram = m.get("size_vram", 0)
                if size:
                    pct = int((size_vram / size) * 100)
                    self.result.emit(f"{pct}%")
                    return
        self.result.emit("")


class Input(QPlainTextEdit):
    submit = pyqtSignal()

    def keyPressEvent(self, e):
        enter = e.key() in (Qt.Key.Key_Return, Qt.Key.Key_Enter)
        if enter and not e.modifiers() & Qt.KeyboardModifier.ShiftModifier:
            self.submit.emit()
            return
        super().keyPressEvent(e)


class Win(QWidget):
    def __init__(self, colors):
        super().__init__()
        self.c = colors
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, True)

        self.setWindowTitle("󰣇  ollama chat")
        self.resize(920, 740)

        self.history = []
        self.items = []            # transcript blocks (notes, prompts, replies)
        self.turn = 0
        self.nav = -1              # Alt+Up/Down position in the anchor list
        self.reply = ""
        self.pending = ""          # tokens waiting to be flushed to the view
        self.stream_started = False
        self.thinking = False
        self.err = ""
        self.worker = None
        self.pull_worker = None
        self.delete_worker = None
        self.server_worker = None
        self.install_ollama_worker = None
        self.gpu_worker = None
        self.backend_worker = None
        self.rocm_install_worker = None
        self.vulkan_install_worker = None
        self.installed_tags = set()
        self.current_tier = DEFAULT_TIER

        # Batches streamed tokens so the view updates ~25 times a second
        # instead of once per token.
        self.flush_timer = QTimer(self)
        self.flush_timer.setInterval(FLUSH_MS)
        self.flush_timer.timeout.connect(self.flush_stream)

        self.view = QTextBrowser()
        self.view.setOpenExternalLinks(True)
        self.view.document().setDefaultStyleSheet(
            f"h1, h2, h3, h4 {{ color: {self.c['accent']}; }}"
            f"p, li {{ line-height: 140%; }}"
            f"a {{ color: {self.c['accent']}; }}"
        )

        self.tier = QComboBox()
        self.tier.addItem("󰇄 Desktop (dGPU)", "desktop")
        self.tier.addItem("󰢠 Laptop (iGPU/CPU)", "lite")

        self.models = QComboBox()
        self.populate_models(DEFAULT_TIER)

        self.ctx = QComboBox()
        for tokens in CTX_OPTIONS:
            label = f"{tokens // 1024}k ctx" if tokens >= 1024 else f"{tokens} ctx"
            self.ctx.addItem(label, tokens)
        self.ctx.setCurrentIndex(CTX_OPTIONS.index(DEFAULT_CTX))

        self.think = QCheckBox("󰚩 think")
        self.action_btn = QPushButton()
        self.action_btn.setVisible(False)
        self.clear = QPushButton("󰃢 clear")

        top = QHBoxLayout()
        top.addWidget(self.tier)
        top.addWidget(self.models, 1)
        top.addWidget(self.ctx)
        top.addWidget(self.think)
        top.addWidget(self.action_btn)
        top.addWidget(self.clear)

        self.backend_lbl = QLabel("󰢮 checking GPU backend...")
        self.rocm_btn = QPushButton()
        self.rocm_btn.setVisible(False)
        self.vulkan_btn = QPushButton("󰢮 install Vulkan drivers")
        self.vulkan_btn.setVisible(False)
        self.recheck_btn = QPushButton("󰑓 recheck")

        gpu_row = QHBoxLayout()
        gpu_row.addWidget(self.backend_lbl, 1)
        gpu_row.addWidget(self.rocm_btn)
        gpu_row.addWidget(self.vulkan_btn)
        gpu_row.addWidget(self.recheck_btn)

        self.input = Input()
        self.input.setPlaceholderText(
            "Enter to send, Shift+Enter for newline, Alt+Up/Down to jump between messages...")
        self.input.setFixedHeight(84)

        self.send = QPushButton("󰒭 send")
        self.send.setObjectName("send_btn")
        self.send.setFixedHeight(84)

        self.status_lbl = QLabel("󰄬 ready")
        self.gpu_lbl = QLabel("")
        self.gpu_lbl.setObjectName("gpu_lbl")

        bottom = QHBoxLayout()
        bottom.setSpacing(0)
        bottom.addWidget(self.status_lbl)
        bottom.addSpacing(8)
        bottom.addWidget(self.gpu_lbl)
        bottom.addSpacing(12)
        bottom.addWidget(self.input, 1)
        bottom.addWidget(self.send)

        lay = QVBoxLayout(self)
        lay.setContentsMargins(16, 16, 16, 16)
        lay.setSpacing(12)
        lay.addLayout(top)
        lay.addLayout(gpu_row)
        lay.addWidget(self.view, 1)
        lay.addLayout(bottom)

        self.send.clicked.connect(self.go)
        self.input.submit.connect(self.go)
        self.tier.currentIndexChanged.connect(self.on_tier_changed)
        self.models.currentIndexChanged.connect(self.check_selected_model_status)
        self.action_btn.clicked.connect(self.handle_action_click)
        self.clear.clicked.connect(self.reset)
        self.rocm_btn.clicked.connect(self.handle_rocm_btn)
        self.vulkan_btn.clicked.connect(self.handle_vulkan_btn)
        self.recheck_btn.clicked.connect(self.start_backend_check)

        QShortcut(QKeySequence("Alt+Up"), self, activated=lambda: self.jump(-1))
        QShortcut(QKeySequence("Alt+Down"), self, activated=lambda: self.jump(1))

        self.input.setFocus()
        self.init_server()
        self.start_backend_check()

    # ---------- transcript rendering ----------

    def add_note(self, text, err=False, prog=False):
        self.items.append({"k": "note", "t": text, "err": err, "prog": prog})

    def set_note(self, text, err=False):
        self.items = []
        self.add_note(text, err)

    def item_html(self, it):
        c = self.c
        if it["k"] == "note":
            col = c["error"] if it["err"] else c["accent"]
            return (f'<table width="100%" cellspacing="0" cellpadding="8"><tr>'
                    f'<td bgcolor="{c["surface"]}">'
                    f'<span style="color:{col}">{htmllib.escape(it["t"])}</span>'
                    f'</td></tr></table>')

        if it["k"] == "user":
            body = htmllib.escape(it["t"]).replace("\n", "<br>")
            return (f'<table width="100%" cellspacing="0" cellpadding="10"><tr>'
                    f'<td bgcolor="{c["surface"]}">'
                    f'<a name="{it["id"]}"><span style="color:{c["user"]}; '
                    f'font-weight:600">󰊠 You</span></a><br>{body}'
                    f'</td></tr></table>')

        # bot reply
        head = (f'<a name="{it["id"]}"><span style="color:{c["accent"]}; '
                f'font-weight:600">󰚩 {htmllib.escape(it["tag"])}</span></a>')
        if it["t"] is None:
            # Still streaming: header only, tokens are appended below it.
            return f'<p style="margin:0">{head}</p>'
        return (f'<table width="100%" cellspacing="0" cellpadding="0"><tr>'
                f'<td width="4" bgcolor="{c["accent"]}"></td>'
                f'<td width="14"></td>'
                f'<td>{head}{md_to_html(it["t"], c)}</td>'
                f'</tr></table>')

    def anchors(self):
        return [it["id"] for it in self.items if it["k"] in ("user", "bot")]

    def render(self, anchor=None):
        spacer = '<p style="margin:0; font-size:6pt">&nbsp;</p>'
        self.view.setHtml(spacer.join(self.item_html(it) for it in self.items))
        if anchor:
            QTimer.singleShot(0, lambda: self.view.scrollToAnchor(anchor))
        else:
            bar = self.view.verticalScrollBar()
            bar.setValue(bar.maximum())

    def jump(self, step):
        a = self.anchors()
        if not a:
            return
        self.nav = max(0, min(len(a) - 1, (self.nav if self.nav >= 0 else len(a) - 1) + step))
        self.view.scrollToAnchor(a[self.nav])

    # ---------- model / tier ----------

    def populate_models(self, tier):
        self.current_tier = tier
        self.models.blockSignals(True)
        self.models.clear()
        for desc, tag in MODEL_TIERS[tier]:
            self.models.addItem(desc, tag)
        self.models.blockSignals(False)

    def on_tier_changed(self):
        tier = self.tier.currentData()
        self.populate_models(tier)
        self.check_selected_model_status()

    # ---------- GPU backend ----------

    def start_backend_check(self):
        if self.backend_worker and self.backend_worker.isRunning():
            return
        self.backend_lbl.setText("󰢮 checking GPU backend...")
        self.rocm_btn.setVisible(False)
        self.vulkan_btn.setVisible(False)
        self.backend_worker = BackendCheckThread()
        self.backend_worker.result.connect(self.on_backend_checked)
        self.backend_worker.start()

    def on_backend_checked(self, info):
        if info["is_integrated"] and self.tier.currentData() != "lite":
            self.tier.blockSignals(True)
            self.tier.setCurrentIndex(self.tier.findData("lite"))
            self.tier.blockSignals(False)
            self.populate_models("lite")
            self.check_selected_model_status()

        # The biggest cause of "slow": the stock `ollama` package is
        # CPU-only. Flag it first and offer the right package.
        if find_ollama() and not info["ollama_gpu_build"]:
            if info["is_integrated"]:
                self.backend_lbl.setText(
                    "⚠ Ollama is the CPU-only build — install ollama-vulkan for GPU")
                self.vulkan_btn.setText("󰢮 install ollama-vulkan")
                self.vulkan_btn.setVisible(True)
                self.rocm_btn.setVisible(False)
            else:
                self.backend_lbl.setText(
                    "⚠ Ollama is the CPU-only build — install ollama-rocm for GPU")
                self.rocm_btn.setText("󰢮 install ollama-rocm")
                self.rocm_btn.setVisible(True)
                self.vulkan_btn.setText("󰢮 install ollama-vulkan")
                self.vulkan_btn.setVisible(True)
            return

        if info["backend"] == "rocm":
            gfx = ", ".join(info["rocm_gfx"]) or "unknown"
            self.backend_lbl.setText(f"󰢮 ROCm active ({gfx})")
            self.rocm_btn.setVisible(False)
            self.vulkan_btn.setVisible(False)

        elif info["backend"] == "vulkan":
            dev = info["vulkan_devices"][0] if info["vulkan_devices"] else "GPU"
            kind = " · iGPU" if info["is_integrated"] else ""
            self.backend_lbl.setText(f"󰢮 Vulkan active ({dev}{kind})")
            self.rocm_btn.setVisible(False)
            self.vulkan_btn.setVisible(False)

        else:
            if info["rocm_installed"] and info["rocm_gfx"] and not info["rocm_session_groups_ok"]:
                self.backend_lbl.setText(
                    "󰢮 ROCm installed but needs a logout/reboot to activate GPU group access"
                )
                self.rocm_btn.setVisible(False)
            elif info["rocm_installed"] and info["rocm_gfx"] and not info["rocm_db_groups_ok"]:
                self.backend_lbl.setText("󰢮 ROCm installed, GPU groups not set up")
                self.rocm_btn.setText("󰢮 add render/video groups")
                self.rocm_btn.setVisible(True)
            else:
                self.backend_lbl.setText("⚠ No GPU acceleration detected — running on CPU")
                self.rocm_btn.setText("󰢮 install ollama-rocm")
                self.rocm_btn.setVisible(True)
                self.vulkan_btn.setText("󰢮 install ollama-vulkan")
                self.vulkan_btn.setVisible(True)

    def handle_rocm_btn(self):
        self.rocm_btn.setEnabled(False)
        user = getpass.getuser()
        if "groups" in self.rocm_btn.text():
            cmd = f"usermod -aG render,video {user}"
        else:
            # ollama-rocm replaces the CPU-only `ollama` package (conflict
            # auto-accepted), pulls the ROCm runtime, and the service is
            # restarted if it is managed by systemd.
            cmd = (f"pacman -S --noconfirm --ask=4 ollama-rocm rocminfo "
                   f"&& usermod -aG render,video {user} "
                   f"&& (systemctl try-restart ollama || true)")
        self.rocm_install_worker = PacmanThread(cmd)
        self.rocm_install_worker.finished.connect(self.on_rocm_fix_finished)
        self.rocm_install_worker.start()

    def on_rocm_fix_finished(self, success, err_msg):
        self.rocm_btn.setEnabled(True)
        if success:
            self.backend_lbl.setText("󰢮 done — fully quit this app, log out/reboot, then recheck")
            self.rocm_btn.setVisible(False)
            self.vulkan_btn.setVisible(False)
        else:
            self.backend_lbl.setText(f"⚠ ROCm fix failed: {err_msg}")

    def handle_vulkan_btn(self):
        self.vulkan_btn.setEnabled(False)
        cmd = ("pacman -S --noconfirm --ask=4 ollama-vulkan vulkan-icd-loader "
               "vulkan-radeon vulkan-intel vulkan-tools "
               "&& (systemctl try-restart ollama || true)")
        self.vulkan_install_worker = PacmanThread(cmd)
        self.vulkan_install_worker.finished.connect(self.on_vulkan_install_finished)
        self.vulkan_install_worker.start()

    def on_vulkan_install_finished(self, success, err_msg):
        self.vulkan_btn.setEnabled(True)
        if success:
            self.backend_lbl.setText("󰢮 Vulkan installed — restart this app, then recheck")
            self.vulkan_btn.setVisible(False)
        else:
            self.backend_lbl.setText(f"⚠ Vulkan install failed: {err_msg}")

    # ---------- server ----------

    def init_server(self):
        if not find_ollama():
            self.set_note("⚠ Ollama is not installed. Click the button above to install it via pacman.", err=True)
            self.action_btn.setText("󰚰 install ollama")
            self.action_btn.setVisible(True)
            self.status_lbl.setText("󰅚 missing")
            self.render()
            return

        self.status_lbl.setText("󰔟 starting...")
        self.set_note("⏳ Starting Ollama service in the background...")
        self.render()
        self.server_worker = ServerInitThread()
        self.server_worker.ready.connect(self.on_server_ready)
        self.server_worker.start()

    def on_server_ready(self, err_msg):
        if err_msg:
            self.status_lbl.setText("󰅚 error")
            self.set_note(f"⚠ Background service error: {err_msg}", err=True)
            self.render()
        self.load_installed_models()

    def load_installed_models(self):
        if not find_ollama():
            return

        ollama_online = False
        self.installed_tags = set()
        try:
            with urllib.request.urlopen(f"{HOST}/api/tags", timeout=3) as r:
                data = json.load(r)
                self.installed_tags = {m["name"] for m in data.get("models", [])}
                ollama_online = True
        except Exception:
            pass

        if not ollama_online:
            self.status_lbl.setText("󰖪 offline")
            self.action_btn.setText("󰚰 install selected")
            self.action_btn.setVisible(True)
            self.set_note(f"⚠ Can't reach Ollama at {HOST}. Please ensure `ollama serve` is running.", err=True)
            self.render()
            return

        self.status_lbl.setText("󰄬 ready")
        self.check_selected_model_status()

    def check_selected_model_status(self):
        if not find_ollama():
            return

        self.gpu_lbl.setText("")
        current_tag = self.models.currentData()
        if current_tag in self.installed_tags:
            self.action_btn.setText("󰆴 delete model")
            self.action_btn.setVisible(True)
            self.items = []
        else:
            self.action_btn.setText(f"󰚰 download {current_tag}")
            self.action_btn.setVisible(True)
            self.set_note(f"󰌵 Selected model {current_tag} is not installed yet. Click above to download it.")
        self.render()

    def handle_action_click(self):
        if not find_ollama():
            self.action_btn.setEnabled(False)
            self.status_lbl.setText("󰚰 installing...")
            self.add_note("⚙ Prompting for password to install Ollama via pacman...")
            self.render()
            # Pick the GPU-capable build up front instead of the CPU-only one.
            pkg = "ollama-vulkan" if self.tier.currentData() == "lite" else "ollama-rocm"
            self.install_ollama_worker = PacmanThread(
                f"pacman -S --noconfirm --ask=4 {pkg}", timeout=900)
            self.install_ollama_worker.finished.connect(self.on_ollama_installed)
            self.install_ollama_worker.start()
        else:
            current_tag = self.models.currentData()
            if current_tag in self.installed_tags:
                self.start_model_delete()
            else:
                self.start_model_pull()

    def on_ollama_installed(self, success, err_msg):
        self.action_btn.setEnabled(True)
        if success:
            self.add_note("✔ Successfully installed Ollama!")
            self.init_server()
            self.start_backend_check()
        else:
            self.status_lbl.setText("󰅚 failed")
            self.add_note(f"⚠ Failed to install ollama: {err_msg}", err=True)
            self.render()

    def start_model_pull(self):
        if self.pull_worker and self.pull_worker.isRunning():
            return
        current_tag = self.models.currentData()
        self.action_btn.setEnabled(False)
        self.status_lbl.setText("󰉁 downloading")
        self.add_note(f"⬇ Starting download for {current_tag}...", prog=True)
        self.render()

        self.pull_worker = PullThread(current_tag)
        self.pull_worker.progress.connect(self.on_install_progress)
        self.pull_worker.finished.connect(self.on_install_finished)
        self.pull_worker.start()

    def on_install_progress(self, msg):
        if self.items and self.items[-1].get("prog"):
            self.items[-1]["t"] = f"⬇ {msg}"
        else:
            self.add_note(f"⬇ {msg}", prog=True)
        self.render()

    def on_install_finished(self, success, err_msg):
        self.action_btn.setEnabled(True)
        current_tag = self.models.currentData()
        if self.items and self.items[-1].get("prog"):
            self.items[-1]["prog"] = False
        if success:
            self.status_lbl.setText("󰄬 ready")
            self.add_note(f"✔ Successfully installed {current_tag}!")
            self.load_installed_models()
        else:
            self.status_lbl.setText("󰅚 failed")
            self.add_note(f"⚠ Installation failed: {err_msg}", err=True)
            self.render()

    def start_model_delete(self):
        if self.delete_worker and self.delete_worker.isRunning():
            return
        current_tag = self.models.currentData()
        self.action_btn.setEnabled(False)
        self.status_lbl.setText("󰆴 deleting...")
        self.add_note(f"🗑 Deleting model {current_tag}...")
        self.render()

        self.delete_worker = DeleteThread(current_tag)
        self.delete_worker.finished.connect(self.on_delete_finished)
        self.delete_worker.start()

    def on_delete_finished(self, success, err_msg):
        self.action_btn.setEnabled(True)
        current_tag = self.models.currentData()
        if success:
            self.status_lbl.setText("󰄬 ready")
            self.add_note(f"✔ Successfully deleted {current_tag}.")
            self.load_installed_models()
        else:
            self.status_lbl.setText("󰅚 failed")
            self.add_note(f"⚠ Failed to delete model: {err_msg}", err=True)
            self.render()

    # ---------- chat ----------

    def go(self):
        if self.worker and self.worker.isRunning():
            self.worker.halt()
            return
        text = self.input.toPlainText().strip()
        if not text:
            return
        self.input.clear()

        self.history.append({"role": "user", "content": text})
        current_tag = self.models.currentData()
        self.turn += 1
        self.items.append({"k": "user", "t": text, "id": f"u{self.turn}"})
        self.items.append({"k": "bot", "tag": current_tag, "t": None, "id": f"r{self.turn}"})
        self.reply, self.pending, self.err = "", "", ""
        self.thinking = False
        self.stream_started = False
        self.nav = -1
        self.render()

        self.send.setText("󰓛 stop")
        self.status_lbl.setText("󰚩 thinking..." if self.think.isChecked() else "󰚩 working...")

        num_ctx = self.ctx.currentData()
        self.worker = Stream(current_tag, self.history, self.think.isChecked(), num_ctx)
        self.worker.chunk.connect(self.on_chunk)
        self.worker.failed.connect(self.on_fail)
        self.worker.finished.connect(self.done)
        self.worker.start()

    def on_chunk(self, kind, text):
        if kind == "think":
            self.thinking = True
            self.status_lbl.setText("󰚩 thinking...")
            return
        self.thinking = False
        self.status_lbl.setText("󰕑 streaming...")
        self.reply += text
        self.pending += text
        if not self.flush_timer.isActive():
            self.flush_timer.start()

    def flush_stream(self):
        """Append buffered tokens to the end of the document as plain text.
        No markdown re-parse and no full document reset, so no flicker."""
        if not self.pending:
            self.flush_timer.stop()
            return

        bar = self.view.verticalScrollBar()
        at_bottom = bar.value() >= bar.maximum() - 4

        cursor = QTextCursor(self.view.document())
        cursor.movePosition(QTextCursor.MoveOperation.End)
        if not self.stream_started:
            # Start a fresh block with default formatting so the reply
            # doesn't inherit the style of the model-name header.
            cursor.insertBlock()
            cursor.setCharFormat(QTextCharFormat())
            self.stream_started = True
        cursor.insertText(self.pending)
        self.pending = ""

        # Only follow the stream if the user hasn't scrolled up to read.
        if at_bottom:
            bar.setValue(bar.maximum())

    def on_fail(self, msg):
        self.err = msg

    def done(self):
        self.flush_timer.stop()
        self.pending = ""
        bot = self.items[-1] if self.items and self.items[-1]["k"] == "bot" else None
        reply_id = None

        if self.reply:
            self.history.append({"role": "assistant", "content": self.reply})
            if bot:
                bot["t"] = self.reply
                reply_id = bot["id"]
            if self.err:
                self.add_note(f"⚠ Response cut short: {self.err}", err=True)
        else:
            # Nothing came back — drop the user turn so a retry doesn't
            # carry a dangling, unanswered message in context.
            if self.history:
                self.history.pop()
            if bot:
                bot["t"] = "(no response)"
            if self.err:
                self.add_note(f"⚠ {self.err}", err=True)

        current_tag = self.models.currentData()
        self.reply, self.thinking = "", False
        self.send.setText("󰒭 send")
        self.status_lbl.setText("󰄬 ready")

        # One full render now that the reply is complete. Jump to the START
        # of the reply so you read top-down instead of landing at the end.
        self.render(anchor=reply_id)
        self.nav = len(self.anchors()) - 1

        self.gpu_worker = GpuCheckThread(current_tag)
        self.gpu_worker.result.connect(self.on_gpu_result)
        self.gpu_worker.start()

    def on_gpu_result(self, pct):
        if pct:
            self.gpu_lbl.setText(f"󰢮 {pct} GPU")
        else:
            self.gpu_lbl.setText("")

    def reset(self):
        if self.worker and self.worker.isRunning():
            self.worker.halt()
            self.worker.wait()
        self.flush_timer.stop()
        self.history, self.items, self.reply, self.pending = [], [], "", ""
        self.turn, self.nav = 0, -1
        self.gpu_lbl.setText("")
        self.init_server()
        self.render()

    def closeEvent(self, e):
        self.flush_timer.stop()
        for w in (self.worker, self.pull_worker, self.delete_worker,
                  self.server_worker, self.install_ollama_worker, self.gpu_worker,
                  self.backend_worker, self.rocm_install_worker, self.vulkan_install_worker):
            if w and w.isRunning():
                if hasattr(w, "halt"):
                    w.halt()
                w.wait(2000)

        global _ollama_proc
        if _ollama_proc and _ollama_proc.poll() is None:
            _ollama_proc.terminate()
            try:
                _ollama_proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                _ollama_proc.kill()

        super().closeEvent(e)


def main():
    app = QApplication(sys.argv)
    app.setFont(QFont(FONT, 11))
    colors = load_colors()
    app.setStyleSheet(style(colors))
    w = Win(colors)
    w.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
