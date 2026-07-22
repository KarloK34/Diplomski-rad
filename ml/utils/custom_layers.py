"""Custom Keras pooling layers for HAR-specific signal processing.

Two pooling operators are provided, loosely inspired by the extrema-based
pooling idea in Ameen, B. A. H., & Aminifar, S. A. (2026). *Robust
Activity Recognition via Redundancy-Aware CNNs and Novel Pooling for
Noisy Mobile Sensor Data.* Sensors, 26(2), 710. DOI 10.3390/s26020710
(evaluated on the WISDM dataset, general HAR — not gait/pocket-specific).

The formulas below are project variants inspired by that paper's
pooling operators, not a literal reproduction. The paper's own ECP/CMV
both start from the midrange ``(max+min)/2`` and subtract a spread term;
this module drops the midrange term entirely (`ECPPooling`) or replaces
it with the arithmetic mean (`CMVPooling`):

* Paper's ECP: ``(max+min)/2 - (max-min)^2/2``. This module's
  :class:`ECPPooling`: ``(max-min)^2`` (squared range only).
* Paper's CMV: ``(max+min)/2 - std``. This module's :class:`CMVPooling`:
  ``mean - std`` (arithmetic mean, not midrange).

* :class:`ECPPooling` — Extrema Contrast Pooling. Computes the squared
  range :math:`(\\max - \\min)^2` over each window.
* :class:`CMVPooling` — Center Minus Variation. Returns the per-window
  mean minus the per-window standard deviation.

Neither layer is part of the shipped model (`models/cnn_final.tflite`):
they were tried in the architecture-comparison sweep
(`12-arch-comparison.ipynb`, variants C/E/F) and all underperformed the
winning `A_baseline`/`D_dilated_reg` variants — dead experimental code
kept in the repository, not on the deployment path.

Both layers operate channel-wise (no cross-channel mixing) and accept
either ``valid`` or ``same`` padding. They are JSON-serialisable via the
standard Keras ``get_config`` / ``from_config`` mechanism so trained
models containing them can be loaded back without registering them
manually.
"""

from __future__ import annotations

import tensorflow as tf
from keras import layers


@tf.keras.utils.register_keras_serializable(package="har_custom")
class ECPPooling(layers.Layer):
    """Extrema Contrast Pooling on 1-D sequences.

    For each pooling window of length ``pool_size`` along the time axis,
    returns :math:`(\\max - \\min)^2`. Computed as a difference of two
    max-pools (a min-pool over ``x`` equals the negative of a max-pool
    over ``-x``). Squared range as a transient-emphasising pooling
    statistic is a project variant inspired by, but not a literal
    reproduction of, the ECP operator in Ameen & Aminifar (2026, module
    docstring) — no source supports specific claims about heel-strike
    detection or hardware-noise invariance for this formula; none are
    made here.
    """

    def __init__(
        self,
        pool_size: int = 2,
        strides: int | None = None,
        padding: str = "valid",
        **kwargs,
    ):
        super().__init__(**kwargs)
        if pool_size < 1:
            raise ValueError("pool_size must be >= 1")
        self.pool_size = pool_size
        self.strides = strides if strides is not None else pool_size
        if padding.lower() not in ("valid", "same"):
            raise ValueError("padding must be 'valid' or 'same'")
        self.padding = padding.lower()

    def call(self, inputs):
        max_pool = tf.nn.max_pool1d(
            inputs,
            ksize=self.pool_size,
            strides=self.strides,
            padding=self.padding.upper(),
        )
        min_pool = -tf.nn.max_pool1d(
            -inputs,
            ksize=self.pool_size,
            strides=self.strides,
            padding=self.padding.upper(),
        )
        return tf.square(max_pool - min_pool)

    def compute_output_shape(self, input_shape):
        # Same as MaxPooling1D in Keras.
        batch, length, channels = input_shape
        if length is None:
            return (batch, None, channels)
        if self.padding == "valid":
            out_len = (length - self.pool_size) // self.strides + 1
        else:
            out_len = -(-length // self.strides)  # ceil division
        return (batch, out_len, channels)

    def get_config(self):
        cfg = super().get_config()
        cfg.update({
            "pool_size": self.pool_size,
            "strides": self.strides,
            "padding": self.padding,
        })
        return cfg


@tf.keras.utils.register_keras_serializable(package="har_custom")
class CMVPooling(layers.Layer):
    """Center Minus Variation pooling on 1-D sequences.

    Per pooling window of length ``pool_size`` returns
    :math:`\\mathrm{mean}(w) - \\mathrm{std}(w)`. Implemented via two
    average-pools (one on ``x`` and one on ``x**2``) so it is fully
    differentiable on TF graph. Mean-minus-std as a pooling statistic is
    a project variant inspired by, but not a literal reproduction of,
    the CMV operator in Ameen & Aminifar (2026, module docstring), which
    uses the midrange ``(max+min)/2`` in place of the mean — no source
    supports the claim that this penalises Android-specific hardware
    noise; none is made here.
    """

    def __init__(
        self,
        pool_size: int = 2,
        strides: int | None = None,
        padding: str = "valid",
        eps: float = 1e-6,
        **kwargs,
    ):
        super().__init__(**kwargs)
        if pool_size < 1:
            raise ValueError("pool_size must be >= 1")
        self.pool_size = pool_size
        self.strides = strides if strides is not None else pool_size
        if padding.lower() not in ("valid", "same"):
            raise ValueError("padding must be 'valid' or 'same'")
        self.padding = padding.lower()
        self.eps = eps

    def call(self, inputs):
        mean = tf.nn.avg_pool1d(
            inputs,
            ksize=self.pool_size,
            strides=self.strides,
            padding=self.padding.upper(),
        )
        sq_mean = tf.nn.avg_pool1d(
            tf.square(inputs),
            ksize=self.pool_size,
            strides=self.strides,
            padding=self.padding.upper(),
        )
        var = tf.maximum(sq_mean - tf.square(mean), 0.0)
        std = tf.sqrt(var + self.eps)
        return mean - std

    def compute_output_shape(self, input_shape):
        batch, length, channels = input_shape
        if length is None:
            return (batch, None, channels)
        if self.padding == "valid":
            out_len = (length - self.pool_size) // self.strides + 1
        else:
            out_len = -(-length // self.strides)
        return (batch, out_len, channels)

    def get_config(self):
        cfg = super().get_config()
        cfg.update({
            "pool_size": self.pool_size,
            "strides": self.strides,
            "padding": self.padding,
            "eps": self.eps,
        })
        return cfg
