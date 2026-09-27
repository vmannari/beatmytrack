"""Read-only environment verification. Run in the Linux generation environment."""
import importlib.metadata as metadata
import json
import platform
import jax
from magenta_rt import paths

devices = jax.devices()
assert any(d.platform == "gpu" for d in devices), "JAX CUDA device required"
assert metadata.version("magenta-rt") == "2.0.3", "Revalidate adapter for changed MRT API"
result = jax.numpy.ones((32, 32)) @ jax.numpy.ones((32, 32))
result.block_until_ready()
assert float(result.sum()) == 32768
print(json.dumps({"python": platform.python_version(),
    "versions": {p: metadata.version(p) for p in ("magenta-rt", "jax", "jaxlib", "PyYAML")},
    "devices": [str(d) for d in devices], "backend": jax.default_backend(),
    "gpu_matmul": "passed", "assets": str(paths.magenta_home()),
    "base_checkpoint_present": (paths.checkpoints_dir() / "mrt2_base.safetensors").is_file()}, indent=2))
