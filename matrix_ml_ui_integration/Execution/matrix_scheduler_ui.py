import re
import subprocess
import threading
import tkinter as tk
from tkinter import ttk, messagebox
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SCRIPT = ROOT / "predict_and_run.py"
VVP = ROOT / "matrix_demo.vvp"
VERILOG = ROOT / "matrix_core_demo.v"

class MatrixSchedulerUI(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("AI-Based Multicore Scheduler | Matrix Lab")
        self.geometry("1120x780")
        self.minsize(900, 650)
        self.configure(bg="#0b1220")
        self._style()
        self._build()

    def _style(self):
        s = ttk.Style(self)
        s.theme_use("clam")
        s.configure("TFrame", background="#0b1220")
        s.configure("Panel.TFrame", background="#121d30")
        s.configure("TLabel", background="#0b1220", foreground="#e5edf8", font=("Segoe UI", 10))
        s.configure("Title.TLabel", font=("Segoe UI", 20, "bold"), foreground="#f8fafc")
        s.configure("Sub.TLabel", font=("Segoe UI", 10), foreground="#9fb0c8")
        s.configure("PanelTitle.TLabel", background="#121d30", foreground="#dce8fa", font=("Segoe UI", 10, "bold"))
        s.configure("Metric.TLabel", background="#121d30", foreground="#f8fafc", font=("Segoe UI", 22, "bold"))
        s.configure("MetricSub.TLabel", background="#121d30", foreground="#9fb0c8", font=("Segoe UI", 9))
        s.configure("TButton", font=("Segoe UI", 10, "bold"), padding=(14, 9))
        s.configure("Accent.TButton", background="#38bdf8", foreground="#06111f")
        s.map("Accent.TButton", background=[("active", "#7dd3fc"), ("disabled", "#475569")])
        s.configure("TCombobox", padding=6)
        s.configure("Treeview", background="#121d30", fieldbackground="#121d30", foreground="#e5edf8", rowheight=28)
        s.configure("Treeview.Heading", background="#20314b", foreground="#e5edf8", font=("Segoe UI", 9, "bold"))
        s.map("Treeview", background=[("selected", "#155e75")])

    def _build(self):
        outer = ttk.Frame(self, padding=22)
        outer.pack(fill="both", expand=True)

        head = ttk.Frame(outer)
        head.pack(fill="x")
        ttk.Label(head, text="AI-BASED MULTICORE SCHEDULER", style="Title.TLabel").pack(anchor="w")
        ttk.Label(head, text="Live matrix multiplication experiment • Predict → Execute → Verify",
                  style="Sub.TLabel").pack(anchor="w", pady=(4, 14))


        controls = ttk.Frame(outer, style="Panel.TFrame", padding=14)
        controls.pack(fill="x")
        ttk.Label(controls, text="EXPERIMENT CONFIGURATION", style="PanelTitle.TLabel").grid(row=0, column=0, sticky="w", columnspan=3)
        ttk.Label(controls, text="Square matrix dimension N").grid(row=1, column=0, sticky="w", pady=(10, 0))
        self.size = tk.StringVar(value="4")
        self.combo = ttk.Combobox(controls, textvariable=self.size, values=["2", "4", "6", "8", "12", "16"], state="readonly", width=10)
        self.combo.grid(row=2, column=0, sticky="w", pady=(4, 0))
        self.run_btn = ttk.Button(controls, text="▶  RUN EXPERIMENT", style="Accent.TButton", command=self.run_experiment)
        self.run_btn.grid(row=2, column=1, padx=(16, 0), sticky="w", pady=(4, 0))
        self.status = tk.StringVar(value="Ready. Select a matrix size and run.")
        ttk.Label(controls, textvariable=self.status, style="Sub.TLabel").grid(row=2, column=2, padx=16, sticky="w")
        controls.columnconfigure(2, weight=1)

        cards = ttk.Frame(outer)
        cards.pack(fill="x", pady=14)
        self.pred = self._metric_card(cards, "MODEL PREDICTION", "—", "selected core count")
        self.cycles = self._metric_card(cards, "PREDICTED CONFIG CYCLES", "—", "from RTL model")
        self.check = self._metric_card(cards, "CORRECTNESS", "—", "element-by-element check")
        self.speedup = self._metric_card(cards, "VS. 1-CORE BASELINE", "—", "cycle reduction")
        for i in range(4):
            cards.columnconfigure(i, weight=1)

        middle = ttk.Frame(outer)
        middle.pack(fill="both", expand=True)
        left = ttk.Frame(middle, style="Panel.TFrame", padding=12)
        left.pack(side="left", fill="both", expand=True, padx=(0, 7))
        right = ttk.Frame(middle, style="Panel.TFrame", padding=12)
        right.pack(side="left", fill="both", expand=True, padx=(7, 0))
        ttk.Label(left, text="CORE CONFIGURATION COMPARISON", style="PanelTitle.TLabel").pack(anchor="w", pady=(0, 8))
        self.table = ttk.Treeview(left, columns=("cores", "cycles", "status"), show="headings", height=5)
        for col, label, width in [("cores", "Active cores", 100), ("cycles", "Simulated cycles", 130), ("status", "Verification", 110)]:
            self.table.heading(col, text=label)
            self.table.column(col, width=width, anchor="center")
        self.table.pack(fill="x")
        ttk.Label(left, text="RESULT MATRIX (selected prediction)", style="PanelTitle.TLabel").pack(anchor="w", pady=(18, 8))
        self.matrix = tk.Text(left, height=10, bg="#08111f", fg="#a7f3d0", insertbackground="white",
                              relief="flat", font=("Consolas", 10), padx=10, pady=10, wrap="none")
        self.matrix.pack(fill="both", expand=True)
        self.matrix.insert("1.0", "Run an experiment to display the computed matrix.")
        self.matrix.configure(state="disabled")

        ttk.Label(right, text="RUN LOG / EVIDENCE", style="PanelTitle.TLabel").pack(anchor="w", pady=(0, 8))
        self.log = tk.Text(right, bg="#08111f", fg="#dbeafe", insertbackground="white", relief="flat",
                           font=("Consolas", 9), padx=10, pady=10, wrap="word")
        self.log.pack(fill="both", expand=True)
        self.log.insert("1.0", "The run log will show model inference, each core-count candidate, output checks, and cycle counts.")
        self.log.configure(state="disabled")

        footer = ttk.Label(outer, text="Cycle counts are model-based simulation estimates, not physical-chip timing or measured energy.",
                           style="Sub.TLabel")
        footer.pack(anchor="w", pady=(12, 0))

    def _metric_card(self, parent, title, value, subtitle):
        f = ttk.Frame(parent, style="Panel.TFrame", padding=13)
        f.pack(side="left", fill="both", expand=True, padx=4)
        ttk.Label(f, text=title, style="PanelTitle.TLabel").pack(anchor="w")
        val = ttk.Label(f, text=value, style="Metric.TLabel")
        val.pack(anchor="w", pady=(8, 0))
        ttk.Label(f, text=subtitle, style="MetricSub.TLabel").pack(anchor="w", pady=(2, 0))
        return val

    def set_text(self, widget, content):
        widget.configure(state="normal")
        widget.delete("1.0", "end")
        widget.insert("1.0", content)
        widget.configure(state="disabled")

    def run_experiment(self):
        if not SCRIPT.exists() or not VERILOG.exists():
            messagebox.showerror("Missing files", "Keep matrix_scheduler_ui.py, predict_and_run.py, and matrix_core_demo.v in the same folder.")
            return
        self.run_btn.configure(state="disabled")
        self.status.set("Compiling and running candidates…")
        self.set_text(self.log, "Starting experiment…")
        threading.Thread(target=self._worker, args=(int(self.size.get()),), daemon=True).start()

    def _worker(self, n):
        try:
            compile_result = subprocess.run(
                ["iverilog", "-g2012", "-s", "matrix_core_demo", "-o", str(VVP), str(VERILOG)],
                cwd=ROOT, capture_output=True, text=True, timeout=30
            )
            if compile_result.returncode != 0:
                raise RuntimeError("Verilog compile failed:\n" + compile_result.stdout + compile_result.stderr)
            proc = subprocess.run(
                [__import__("sys").executable, str(SCRIPT), str(n)],
                cwd=ROOT, capture_output=True, text=True, timeout=120
            )
            output = proc.stdout + ("\n" + proc.stderr if proc.stderr else "")
            if proc.returncode != 0:
                raise RuntimeError(output or "Experiment failed.")
            self.after(0, self._show_results, n, output)
        except Exception as e:
            self.after(0, self._show_error, str(e))

    def _show_error(self, msg):
        self.run_btn.configure(state="normal")
        self.status.set("Run failed")
        self.set_text(self.log, msg)
        messagebox.showerror("Experiment failed", msg[:1800])

    def _show_results(self, n, output):
        self.run_btn.configure(state="normal")
        self.status.set(f"Completed: {n}×{n}; all candidate outputs checked.")
        prediction_match = re.search(r"MODEL_PREDICTION,matrix_size=\d+,selected_cores=(\d+)", output)
        predicted = int(prediction_match.group(1)) if prediction_match else None
        blocks = re.split(r"--- Candidate: (\d+) core\(s\) ---\n", output)
        candidates = {}
        for idx in range(1, len(blocks), 2):
            cores = int(blocks[idx])
            body = blocks[idx+1]
            cm = re.search(r"SIMULATED_CYCLES=(\d+)", body)
            matrix_part = body.split("RESULT_MATRIX\n", 1)[1].split("DEMO_STATUS", 1)[0].strip() if "RESULT_MATRIX\n" in body else ""
            status = "PASS" if "DEMO_STATUS,PASS" in body and "errors=0,status=PASS" in body else "FAIL"
            candidates[cores] = {"cycles": int(cm.group(1)) if cm else None, "matrix": matrix_part, "status": status}
        for item in self.table.get_children():
            self.table.delete(item)
        for c in (1,2,4):
            d = candidates.get(c, {})
            self.table.insert("", "end", values=(c, d.get("cycles", "—"), d.get("status", "MISSING")))
        selected = candidates.get(predicted, {})
        base = candidates.get(1, {}).get("cycles")
        chosen = selected.get("cycles")
        self.pred.configure(text=f"{predicted} cores" if predicted else "N/A")
        self.cycles.configure(text=str(chosen) if chosen is not None else "N/A")
        self.check.configure(text=selected.get("status", "N/A"))
        if base and chosen is not None:
            reduction = (base-chosen)/base*100
            self.speedup.configure(text=f"{reduction:.1f}%")
        else:
            self.speedup.configure(text="N/A")
        self.set_text(self.matrix, selected.get("matrix", "No matrix output found."))
        self.set_text(self.log, "VERILOG COMPILE: PASS\n\n" + output)
        if any(v.get("status") != "PASS" for v in candidates.values()):
            self.status.set("Completed with a candidate verification issue")
        else:
            self.status.set(f"PASS — {n}×{n} matrix, prediction {predicted} core(s)")

if __name__ == "__main__":
    MatrixSchedulerUI().mainloop()
