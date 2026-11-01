"""Prepara i modelli RapidOCR per l'app Flutter.

Prende i modelli ONNX dal pacchetto `rapidocr_onnxruntime` (gli stessi usati da
PyReceipt) e li scrive in assets/models/:

- det.onnx  : rilevatore DBNet (PP-OCRv4), copiato così com'è
- cls.onnx  : classificatore di orientamento 0/180, copiato così com'è
- rec.onnx  : riconoscitore CRNN (PP-OCRv4) con ArgMax + ReduceMax aggiunti in
              coda, così l'app riceve [N, T] indici e confidenze invece di
              [N, T, 6625] probabilità (stesso risultato, ~6000x meno dati)
- keys.txt  : dizionario dei caratteri, letto dai metadati del modello

Uso:
    python tools/export_models.py [cartella_modelli_rapidocr]
"""

import shutil
import sys
from pathlib import Path

import onnx
from onnx import helper

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "models"


def default_models_dir() -> Path:
    import rapidocr_onnxruntime

    return Path(rapidocr_onnxruntime.__file__).parent / "models"


def add_argmax(model: onnx.ModelProto) -> onnx.ModelProto:
    graph = model.graph
    probs = graph.output[0].name
    opset = next(o.version for o in model.opset_import if o.domain in ("", "ai.onnx"))

    argmax = helper.make_node("ArgMax", [probs], ["indices"], axis=2, keepdims=0)
    if opset >= 18:
        axes = helper.make_tensor("reduce_axes", onnx.TensorProto.INT64, [1], [2])
        graph.initializer.append(axes)
        reducemax = helper.make_node("ReduceMax", [probs, "reduce_axes"], ["scores"], keepdims=0)
    else:
        reducemax = helper.make_node("ReduceMax", [probs], ["scores"], axes=[2], keepdims=0)
    graph.node.extend([argmax, reducemax])

    del graph.output[:]
    graph.output.extend([
        helper.make_tensor_value_info("indices", onnx.TensorProto.INT64, ["N", "T"]),
        helper.make_tensor_value_info("scores", onnx.TensorProto.FLOAT, ["N", "T"]),
    ])
    onnx.checker.check_model(model)
    return model


def main() -> None:
    src = Path(sys.argv[1]) if len(sys.argv) > 1 else default_models_dir()
    OUT.mkdir(parents=True, exist_ok=True)

    shutil.copy(src / "ch_PP-OCRv4_det_infer.onnx", OUT / "det.onnx")
    shutil.copy(src / "ch_ppocr_mobile_v2.0_cls_infer.onnx", OUT / "cls.onnx")

    rec = onnx.load(src / "ch_PP-OCRv4_rec_infer.onnx")
    meta = {p.key: p.value for p in rec.metadata_props}
    (OUT / "keys.txt").write_text(meta["character"], encoding="utf-8")
    onnx.save(add_argmax(rec), OUT / "rec.onnx")

    for f in sorted(OUT.iterdir()):
        print(f"{f.name:10s} {f.stat().st_size / 1e6:6.2f} MB")


if __name__ == "__main__":
    main()
