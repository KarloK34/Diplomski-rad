"""Custom Keras pooling layers for HAR-specific signal processing.

Two pooling operators are provided, both motivated by the
*Redundancy-Aware CNN* analysis of Liu et al. (2024, PMC12845535) and
adapted to 1-D IMU windows.

* :class:`ECPPooling` — Extrema Contrast Pooling. Computes the squared
  range :math:`(\\max - \\min)^2` over each window. Emphasises sharp
  transients (heel strike at the start of a downstairs step, foot
  push-off in jogging) and is approximately invariant to slowly varying
  hardware-specific bias.
* :class:`CMVPooling` — Center Minus Variation. Returns the per-window
  mean minus the per-window standard deviation. Penalises high-frequency
  hardware noise that Android phones tend to produce under load.

Both layers operate channel-wise (no cross-channel mixing) and accept
either ``valid`` or ``same`` padding. They are JSON-serialisable via the
standard Keras ``get_config`` / ``from_config`` mechanism so trained
models containing them can be loaded back without registering them
manually.

References
----------
Liu, X., Wang, P., Zhang, R., et al. (2024). Robust Activity
Recognition via Redundancy-Aware Convolutional Neural Networks.
PMC12845535. https://pmc.ncbi.nlm.nih.gov/articles/PMC12845535/
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
    over ``-x``).
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
    differentiable on TF graph.
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
